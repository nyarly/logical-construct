module LogicalConstruct
  module GroundControl
    class Setup < Mattock::TaskLib

      default_namespace :setup

      settings(
        :remote_server => nested( :address => nil, :user => "root"),
        :construct_dir => "/var/logical-construct"
      )
      nil_fields :valise, :platform

      def default_configuration(core)
        super
        core.copy_settings_to(self)
      end

      def define
        in_namespace do
          task :collect, [:address, :platform] do |t, args|
            [:address, :platform].each do |field|
              if args[field].nil?
                fail "Need #{field} for setup"
              end
            end
            remote_server.address = args[:address]
            self.platform = args[:platform]
          end

          task_spine(:collect, :local_setup, :remote_groundwork, :remote_config, :remote_setup)
          task :complete => [:local_setup, :remote_setup]
        end

        desc "Set up a remote server to act as a Construct foundation"
        task root_task,[:address, :platform] => self[:complete]
      end

      def default_subtasks
        in_namespace do
          CreateConstructDirectory.new(self)
          build_files = BuildFiles.new(self)
          CopyFiles.new(self, build_files)
          InstallInit.new(self)
        end
      end
    end
  end
end

require 'logical-construct/ground-control/setup/build-files'
require 'logical-construct/ground-control/setup/create-construct-directory'
require 'logical-construct/ground-control/setup/copy-files'
require 'logical-construct/ground-control/setup/install-init'
