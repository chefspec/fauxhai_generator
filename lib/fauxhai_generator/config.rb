require "optparse"
require "yaml"

module FauxhaiGenerator
  class Config
    def initialize
      readiness_check
      @config = load_config
    end

    attr_reader :config

    # parse the command line options
    def options
      # since optparse doesn't have a "required" flag we have to hack one on
      ARGV << "-h" if ARGV.count < 6

      options = {}
      OptionParser.new do |opts|
        opts.banner = "Usage: fauxhai_generator [options]"

        opts.on("-c", "--config FILE_PATH ", "fauxhai_generator config.yml file path. (required)") do |n|
          raise "The passed config file at #{n} does not exist!" unless File.exist?(n)
          options["config_file"] = n
        end

        opts.on("-f", "--key-file FILE_PATH ", "The path to the key used to login to AWS instances. (required)") do |n|
          raise "The passed key file at #{n} does not exist!" unless File.exist?(n)
          options["key_path"] = n
        end

        opts.on("-k", "--key_name KEYNAME ", "The name of the keypair to setup AWS instances with. (required)") do |n|
          options["key_name"] = n
        end

        opts.on("-h", "--help", "Display fauxhai_generator options") do
          puts opts
          exit
        end
      end.parse!
      options
    end

    # fail if things aren't in order
    def readiness_check
      raise "You must run fauxhai_generator from the root of the fauxhai repository!" unless Dir.exist?("lib/fauxhai/platforms")
    end

    # the config in config.yml mixed in with the key_name/key_path passed via CLI
    def load_config
      opts = options
      yaml = YAML.safe_load(File.open(opts["config_file"]))
      yaml["aws"]["key_name"] = opts["key_name"]
      yaml["aws"]["key_path"] = opts["key_path"]
      yaml
    end
  end
end
