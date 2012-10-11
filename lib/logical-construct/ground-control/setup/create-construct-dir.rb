require 'logical-construct/ground-control/run-on-target'

module LogicalConstruct
  class CreateConstructDirectory < RunOnTarget
    default_namespace :construct_directory

    setting(:construct_dir)

    def default_configuration(setup)
      self.construct_dir = setup.construct_dir
      super
    end

    def define
      remote_task(:create, "Create #{construct_dir} on the remote server") do |task|
        task.command = cmd "mkdir", "-p", construct_dir
      end
      task :remote_groundwork => self[:create]
    end
  end
end
