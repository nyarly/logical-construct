require 'logical-construct/target/sinatra-resolver'
module LogicalConstruct
  module Default
    class ResolveConfiguration < Mattock::Tasklib
      default_namespace 'configuration'

      setting :bind, '0.0.0.0'
      setting :port, 51076
      setting :valise

      def default_configuration(provision)
        super
        self.valise = provision.valise
      end

      def define
        in_namespace do
          resolver = LogicalConstruct::SinatraResolver.new do |task|
            task.task_name = "resolve"
            copy_settings_to(task)
          end
        end
      end
    end
  end
end
