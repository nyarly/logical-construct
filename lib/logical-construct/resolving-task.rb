require 'rake/task'
require 'mattock/task'
require 'logical-construct/satisfiable-task'

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
  module SatisfiableManager
    def default_configuration(*configurables)
      super
      self.satisfiables = configurables.find_all do |conf|
        conf.is_a? SatisfiableTask
      end.map{|sat| sat.task}
    end

    def define
      super
      satisfiables.each do |sat|
        sat.enhance([task.name])
      end
    end
  end

  class ResolvingTask < Rake::Task
    include Mattock::TaskMixin
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

  require 'yaml'
  require 'digest'
  module ManifestHandling
    def digest
      @digest ||= Digest::SHA2.new
    end

    def file_checksum(path)
      generate_checksum(File::read(path))
    end

    def generate_checksum(data)
      digest.reset
      digest << data
      digest.hexdigest
    end
  end

  class Manifest < SatisfiableTask
    include SatisfiableManager
    include ManifestHandling

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
        checksum = manifest[path]
        if invalid_checksum(checksum, path)
          File::rename(path, path + ".invalid")
        end
      end
    end
  end

  class GenerateManifest < Mattock::Task
    include ManifestHandling
    setting :hash, {}
    setting :resolutions

    def default_configuration(resolution_host)
      super
      self.resolutions = resolution_host.resolutions
    end

    def data_checksum(path, data)
      hash[path] = generate_checksum(data)
    end

    def action
      resolutions.each_pair do |destination, data|
        data = data.call if data.respond_to? :call
        data = data.read if data.respond_to? :read
        hash[source_path] = generate_checksum(data)
      end
      resolutions[name] = YAML::dump(hash)
    end
  end
end
