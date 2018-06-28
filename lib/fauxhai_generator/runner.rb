require "train"
require "aws-sdk"
require "json"
require "deepsort"

module FauxhaiGenerator
  class Runner
    def config
      @config ||= FauxhaiGenerator::Config.new.config
    end

    # ec2 client object
    def client
      @client ||= ::Aws::EC2::Client.new(region: config["aws"]["region"])
    end

    # ec2 resource object
    def resource
      @resource ||= ::Aws::EC2::Resource.new(region: config["aws"]["region"])
    end

    # return the security group ID
    # find an existing group or create a new one
    def security_group_id
      @id ||= (find_existing_security_group || create_security_group)
    end

    # find any existing security groups named fauxhai_generator
    # to prevent failures if we fail before we cleanup the group
    def find_existing_security_group
      client.describe_security_groups(group_names: ["fauxhai_generator"]).security_groups[0].group_id
    rescue Aws::EC2::Errors::InvalidGroupNotFound
      # we want a nil to be returned
    end

    # create a new fauxhai_generator security group
    def create_security_group
      create_security_group_result = client.create_security_group(
        group_name: "fauxhai_generator",
        description: "A wide open security group for the Fauxhai Generator."
      )

      client.authorize_security_group_ingress(
        group_id: create_security_group_result.group_id,
        ip_permissions: [
          {
            ip_protocol: "tcp",
            from_port: 22,
            to_port: 22,
            ip_ranges: [
              {
                cidr_ip: "0.0.0.0/0"
              }
            ]
          }
        ]
      )
      create_security_group_result.group_id
    end

    # sping up an instance given an AMI
    def create_instance(ami, platform, release)
      puts "Spinning up #{platform} #{release} AMI #{ami}"

      resource.create_instances(
        image_id: ami,
        min_count: 1,
        max_count: 1,
        key_name: config["aws"]["key_name"],
        instance_type: config["aws"]["instance_type"],
        security_group_ids: [security_group_id],
        tag_specifications: [{
          resource_type: "instance",
          tags: [{
            key: "creator",
            value: "fauxhai_generator"
          },
          {
            key: "Name",
            value: "fauxhai_generator #{platform} #{release}"
          }
          ]
        }]
      )
    end

    def terminate_instance(id)
      puts "Terminating instance #{id}"

      resource.instance(id).terminate
    end

    # wait until the instance is ready and print out messaging while we wait
    def wait_until_ready(instance)
      client.wait_until(:instance_status_ok, instance_ids: [instance.first.id]) do |w|
        w.before_wait { puts "  Waiting for instance #{instance.first.id} to be ready" }
      end
    end

    # list all platforms in the config
    def platforms
      config["platforms"].keys
    end

    # Return an array of releases for a given platform
    def releases(platform)
      config["platforms"][platform].keys
    end

    # return the username to use for a given platform
    def user_name(platform)
      case platform
      when "ubuntu"
        "ubuntu"
      when "centos"
        "centos"
      else
        "ec2-user"
      end
    end

    # return the AMI for a platform/release
    def ami(platform, release)
      config["platforms"][platform][release]["ami"]
    end

    def gather_fauxhai_data(ip, plat)
      puts "  Installing Chef/Fauxhai and gathering data"

      train = Train.create("ssh", host: ip, port: 22, user: user_name(plat), key_files: ARGV[1], auth_methods: ["publickey"], connection_retries: 10, connection_retry_sleep: 5, sudo: true)
      conn = train.connection
      conn.run_command("curl -k https://www.chef.io/chef/install.sh | sudo bash --")
      conn.run_command("/opt/chef/embedded/bin/gem install fauxhai --no-ri --no-rdoc")
      dump = conn.run_command("/opt/chef/embedded/bin/fauxhai").stdout
      conn.close
      dump
    end

    def instance_dns_name(id)
      Aws::EC2::Instance.new(id).public_dns_name
    end

    # make sure we haven't left behind security groups or instances
    def cleanup_aws
      puts "Cleaning up any leftover security groups or instances before shutting down."

      terminate_orphan_instances
      delete_security_group
    end

    def terminate_orphan_instances
      begin
        # find any running / pending instances with the tag we assign
        ids = client.describe_instances(filters:[
          { name: "tag:creator", values: ['fauxhai_generator'] }
          ]).reservations.collect { |i| i.instances[0].instance_id if %w(running pending).include?(i.instances[0].state.name) }.compact

        return if ids.empty?

        puts "Terminating instances: #{ids.join(',')}"
        client.terminate_instances({ instance_ids: ids })

        client.wait_until(:instance_terminated, instance_ids: ids) do |w|
          w.before_wait { puts "  Waiting for instance termination to complete." }
        end
      rescue NoMethodError
        # didn't find anything
      end
    end

    def delete_security_group
      begin
        client.delete_security_group({ group_name: "fauxhai_generator"})
      rescue Aws::EC2::Errors::InvalidGroupNotFound
        # Nothing to delete. We're good
      rescue Aws::EC2::Errors::DependencyViolation
        puts "Could not delete the security group due to a resource still using it!"
      end
    end

    # sort everything that comes back to make future diffs easier
    # uses deepsort to make sorting the json easy
    def json_sort(data)
      JSON.pretty_generate(JSON.parse(data).deep_sort)
    end

    def write_data(platform, release, data)
      raise "No data to write for #{platform} #{release}!" if data.empty?
      puts "Writing data file to lib/fauxhai/platforms/#{platform}/#{release}.json"

      out = File.open("lib/fauxhai/platforms/#{platform}/#{release}.json", "w")
      out << json_sort(data)
      out.close
    end

    def run
      begin
        # Spin up each platform release listed in the config and save the fauxhai output
        platforms.each do |plat|
          releases(plat).each do |rel|
            instance = create_instance(ami(plat, rel), plat, rel)
            wait_until_ready(instance)

            dump = gather_fauxhai_data(instance_dns_name(instance.first.id), plat)
            write_data(plat, rel, dump)

            terminate_instance(instance.first.id)
          end
        end
      ensure
        cleanup_aws
      end
    end
  end
end
