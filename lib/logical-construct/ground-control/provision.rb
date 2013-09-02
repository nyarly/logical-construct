require 'mattock'

require 'logical-construct/ground-control/build-plan'

module LogicalConstruct
  module GroundControl
    class Provision < Mattock::Tasklib
      include Mattock::Configurable::DirectoryStructure

      PlanRecord = ::Struct.new(:name, :archive)

      default_namespace :provision

      setting :target_protocol, "http"
      setting(:target_address, nil).isnt(:copiable)
      setting :target_port, 51076

      setting :plan_archives

      dir(:marshalling, "marshall")
      dir(:plan_source, "plans")

      def default_configuration
        super
        self.plan_archives = []
      end

      def resolve_configuration
        resolve_paths
        super
      end

      def define
        in_namespace do
          directory marshalling.absolute_path

          task :collect, [:ipaddr] do |task, args|
            self.target_address = args[:ipaddr]
          end

          manifest = LogicalConstruct::GenerateManifest.new(self) do |manifest|
          end
        end

        desc "Provision :ipaddr with specified configs (optionally: for :role)"
        task root_task, [:ipaddr]
      end

      def plan_task(name, &block)
        plan = BuildPlan.new(self) do |build|
          build.name = name
          yield build if block_given?
        end
        plan_archives << PlanRecord.new(plan.name, plan.archive.absolute_path)
      end

      def plans(*names)
        names.each do |name|
          plan_task(name)
        end
      end
    end
  end
end
