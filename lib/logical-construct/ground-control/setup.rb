module LogicalConstruct
  module GroundControl
    class Setup < Mattock::TaskLib

      default_namespace :setup

      settings(
        :remote_server => nested( :address => nil, :user => "root"),
        :construct_dir => "/var/logical-construct"
      )

      nil_fields :valise

      def default_configuration(core)
        super
        core.copy_settings_to(self)
      end

      def define
        in_namespace do
          task :collect, [:address] do |t, args|
            remote_server.address = args[:address]
          end

          task :local_setup => [:collect]

          task :remote_groundwork => [:local_setup]

          task :remote_config => [:remote_groundwork]

          task :remote_setup => [:remote_config]

          task :complete => [:local_setup, :remote_setup]
        end

        desc "Set up a remote server to act as a Construct foundation"
        task root_task,[:address] => self[:complete]
      end

      def default_subtasks
        in_namespace do
          CreateConstructDirectory.new(self)
          build_files = BuildFiles.new(self)
          CopyFiles.new(self, build_files)
        end
      end
    end
  end
end

require 'logical-construct/ground-control/setup/build-files'
require 'logical-construct/ground-control/setup/create-construct-directory'
require 'logical-construct/ground-control/setup/copy-files'
