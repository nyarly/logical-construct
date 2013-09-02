require 'rake/task'
require 'mattock/task'

module LogicalConstruct

  #This task won't kill the run if it fails - the assumption is that there's a
  #ResolvingTask that depends on this task to make it work.
  #
  #Based on my reasoning about Rake (c.f. ResolvingTask):
  # Each ST should have a configured #needed? that checks it's responsibility
  # Execute needs to catch errors


  module ReverseDependencies
    module Prerequisite
      def postrequisites
        @postrequisites ||= []
      end
      attr_writer :postrequisites

      def add_postrequisite(task)
        @postrequisites |= [task]
      end
    end

    module Postrequisite
      #Adds what amounts to a reverse dep on any
      #satisfiable managers
      def enhance(deps=nil, &block)
        super
        prerequisite_tasks.each do |task|
          if Prerequisite === task
            task.add_postrequisite(task)
          end
        end
      end
    end
  end

  class SatisfiableTask < Mattock::Rake::Task
    def execute(args=nil)
      super
      if application.options.trace and needed?
        $stderr.puts "** Unsatisfied: #{name}"
      end
    rescue Object => ex
      warn "#{ex.class}: #{ex.message} while performing #{name}"
      #Swallowed
    end

    def prefer_file?
      false
    end

    def receive(data)
      return unless needed?
      fulfill(data)
      if data.respond_to? :path
        fulfill_file(data)
      elsif data.respond_to? :read
        fulfill(data.read)
      else
        fulfill(data.to_s)
      end
    end

    def receive_file(file)
      fulfill(file.read)
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

    def prefer_file?
      true
    end

    def criteria(task)
      File::exists?(target_path)
    end

    def fulfill_file(file)
      FileUtils::move(file.path, target_path)
    end

    def fulfill(data)
      File::open(target_path, "w") do |file|
        file.write(data)
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
  module SatisfiableManager
    include ReverseDependencies::Prerequisite

    def default_configuration(*configurables)
      super
      self.satisfiables = configurables.find_all do |conf|
        conf.is_a? SatisfiableTask
      end
    end
  end

  class ResolvingTask < Mattock::Rake::Task
    include SatisfiableManager
    setting :satisfiables, []

    def needed?
      !unsatisfied.empty?
    end

    def unsatisfied
      satisfiables.find_all{|task| task.needed?}
    end

    def execute(args=nil)
      super
      if needed?
        raise "Task #{name} failed to satisfy: #{unsatisfied.inspect}"
      end
    end
  end

  class Manifest < SatisfiableTask
    include SatisfiableManager
    include ResolutionProtocol

    setting :satisfiables, []
    nil_field :manifest

    default_taskname "Manifest"

    def invalid_checksum(checksum, path)
      return false unless File::exists?(path)
      return true if checksum.nil? or checksum.empty?
      return checksum != file_checksum(path)
    end

    def needed?
      manifest.nil?
    end

    def fulfill(data)
      self.manifest = YAML::load(data)
      satisfiables.each do |sat|
        path = sat.target_path
        checksum = manifest[sat.name]
        if invalid_checksum(checksum, path)
          File::rename(path, path + ".invalid")
        end
      end
    end
  end
end
