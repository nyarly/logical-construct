require 'mattock/task'

module LogicalConstruct
  #This task won't kill the run if it fails - the assumption is that there's a
  #ResolvingTask that depends on this task to make it work.
  #
  #Based on my reasoning about Rake (c.f. ResolvingTask):
  # Each ST should have a configured #needed? that checks it's responsibility
  # Execute needs to catch errors
  class SatisfiableTask < Rake::Task
    include Mattock::TaskMixin

    def execute(args=nil)
      super
      if application.options.trace and needed?
        $stderr.puts "** Unsatisfied: #{name}"
      end
    rescue Object => ex
      warn "#{ex.class}: #{ex.message} while performing #{name}"
      #Swallowed
    end

    def receive(data)
      return unless needed?
      fulfill(data)
    end

    def fulfill(string)
    end

    def needed?
      return !criteria(self)
    end

    def criteria(me)
    end
  end

  class SatisfiableFileTask < SatisfiableTask
    setting :target_path

    def criteria(task)
      File::exists?(target_path)
    end

    def fulfill(string)
      File::open(target_path, "w") do |file|
        file.write(string)
      end
    end
  end

  class SatisfiableEnvTask < SatisfiableTask
    setting :target_name

    def criteria(task)
      ENV.has_key?(target_name)
    end

    def fulfill(string)
      ENV[target_name] = string
    end
  end
end
