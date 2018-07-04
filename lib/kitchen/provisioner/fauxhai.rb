# -*- encoding: utf-8 -*-
#
# Author:: Noah Kantrowitz <noah@coderanger.net>
#
# Copyright (C) 2018, Noah Kantrowitz
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "kitchen/provisioner/base"
require "kitchen/provisioner/chef_base"

module Kitchen
  module Provisioner
    class Fauxhai < ChefBase
      default_config :downloads do |provisioner|
        if provisioner.windows_os?
          raise "todo"
        else
          {"/tmp/fauxhai" => "#{provisioner[:kitchen_root]}/_out/#{provisioner.instance.platform.name}.json"}
        end
      end

      def create_sandbox
        Base.instance_method(:create_sandbox).bind(self).call
      end

      def init_command
        base_cmd = if windows_os?
          raise "todo"
        else
          "/opt/chef/embedded/bin/gem install fauxhai --no-ri --no-rdoc"
        end
        prefix_command(wrap_shell_code(sudo(base_cmd)))
      end

      def run_command
        base_cmd = if windows_os?
          raise "todo"
        else
          "/opt/chef/embedded/bin/fauxhai | tee /tmp/fauxhai"
        end
        prefix_command(wrap_shell_code(sudo(base_cmd)))
      end
    end
  end
end
