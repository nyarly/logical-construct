require 'mattock'

require 'logical-construct/ground-control/generate-manifest'
require 'logical-construct/ground-control/build-plan'
require 'logical-construct/protocol/ssh-tunnel'

module LogicalConstruct
  module GroundControl
    class Provision < Mattock::Tasklib
      default_namespace :provision

      setting :target_protocol, "http"
      setting(:target_address, nil).isnt(:copiable)
      setting :local_target_port, 51076
      setting :remote_target_port, 30712

      setting :plan_archives, []

      dir(:marshalling, "marshall")
      dir(:plan_source, "plans")

      def resolve_configuration
        resolve_paths
        super
      end

      def define
        manifest = nil
        in_namespace do
          directory marshalling.absolute_path

          task :collect, [:ipaddr] do |task, args|
            self.target_address = args[:ipaddr]
          end

          tunnel = LogicalConstruct::SSHTunnel.new do |tunnel|
            tunnel.target_address = proxy_value.target_address
            copy_settings_to(tunnel)
            self.local_target_port = tunnel.proxy_value.local_target_port
          end

          manifest = LogicalConstruct::GenerateManifest.new(self)

          start_flight = Mattock::Rake::RemoteCommandTask.define_task(:start_flight => :collect) do |start_flight|
            start_flight.remote_server.address = proxy_value.target_address
            start_flight.command =
              Mattock::CommandLine.new("nohup",
                                       "/opt/logical-construct/bin/flight-deck",
                                       "-C start_server",
                                       "&",
                                       "echo server started")
          end

          start_resolution = Mattock::Rake::RemoteCommandTask.define_task(:start_resolution => :deliver_manifest) do |start_flight|
            start_flight.remote_server.address = proxy_value.target_address
            start_flight.verbose = 3
            start_flight.command =
              Mattock::CommandLine.new("nohup",
                                       "/opt/logical-construct/bin/flight-deck",
                                       "&",
                                       "echo done")
          end

          task manifest.root_task => :collect

          task_spine(:start_flight, :deliver_manifest, :start_resolution, :fulfill_manifest, :complete_provision)
          task :deliver_manifest => manifest[:deliver]
          task :fulfill_manifest => manifest[:fulfill]

          tunnel.wrap(manifest[:deliver])
          tunnel.wrap(manifest[:fulfill])
          task :complete_provision => tunnel[:close_tunnel]
        end

        desc "Provision :ipaddr with specified configs"
        task root_task, [:ipaddr] => self[:complete_provision]
      end

      def plan_task(name, &block)
        plan = BuildPlan.new(self) do |build|
          build.basename = name
          yield build if block_given?
        end
        task self[:manifest] => plan.archive_path

        in_namespace do
          namespace :package do
            desc "Compile and archive plan #{name.inspect}"
            task name => plan.archive_path
          end
        end

        plan_archives << plan.archive_path
      end

      def plans(*names)
        names.each do |name|
          plan_task(name)
        end
      end
    end
  end
end
