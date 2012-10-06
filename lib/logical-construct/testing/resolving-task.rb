require 'logical-construct/resolving-task'

module LogicalConstruct
  module Testing
    class ResolvingTask < ::LogicalConstruct::ResolvingTask
      setting :resolutions, {}

      def action
        unsatisfied_prerequisites.each do |task|
          task.fulfill(resolutions.fetch(task.name))
        end
      end
    end
  end
end
