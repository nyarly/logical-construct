require 'mattock/tasklib'
require 'logical-construct/testing/resolving-task'

module LogicalConstruct
  module Testing
    class ResolveConfiguration < Mattock::Tasklib
      default_namespace 'configuration'

      setting :resolutions, {}

      def default_configuration(provision)
      end

      def define
        in_namespace do
          LogicalConstruct::Testing::ResolvingTask.new do |task|
            task.task_name = "resolve"
            copy_settings_to(task)
          end
        end
      end
    end
  end
end
