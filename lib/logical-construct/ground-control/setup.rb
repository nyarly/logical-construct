module LogicalConstruct
  class Setup < Mattock::TaskLib

    default_namespace :setup

    settings(
      :remote_server => nested( :address => nil, :user => nil),
      :construct_dir => "/var/logical-construct"
    )

    def define
      in_namespace do
        task :collect, [:address] do |t, args|
          @remote_server.address = args[:address]
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
  end
end

require 'logical-construct/ground-control/setup/bundle-setup'
require 'logical-construct/ground-control/setup/create-construct-dir'
require 'logical-construct/ground-control/setup/ensure-env'
require 'logical-construct/ground-control/setup/copy-files'
require 'logical-construct/ground-control/setup/build-files'
