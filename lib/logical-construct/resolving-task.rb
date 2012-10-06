require 'rake/task'
require 'mattock/task'

module LogicalConstruct
  #Ensures that all it's deps are satisfied before proceeding - the action for
  #ResolvingTasks is all about satisfying deps.
  #
  #Key is how Rake invokes tasks:
  #Task runner calls Task#invoke
  #Which is "setup args" and #invoke_with_call_chain
  #which is
  #  return if @already_invoked
  #  and #invoke_prerequisites
  #    which is prereqs.each{|pr| pr.invoke_with_call_chain }
  #  and #execute if needed
  #
  #So, of note: you'll only get invoked once, ever
  #You'll only be executed if #needed?
  #Deps will get invoked (ish) even if not #needed?
  #
  class ResolvingTask < Rake::Task
    include Mattock::TaskMixin
    def needed?
      prerequisite_tasks.any?{|task| task.needed?}
    end

    def unsatisfied_prerequisites
      prerequisite_tasks.find_all{|task| task.needed?}
    end

    def execute(args=nil)
      super
      if needed?
        raise "Task #{name} failed to satisfy: #{unsatisfied_prerequisites.inspect}"
      end
    end
  end
end
