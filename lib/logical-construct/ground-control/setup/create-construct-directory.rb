require 'logical-construct/ground-control/run-on-target'

module LogicalConstruct
  class CreateConstructDirectory < RunOnTarget
    default_namespace :construct_directory

    setting(:construct_dir)

    def default_configuration(setup)
      self.construct_dir = setup.construct_dir
      self.remote_server = setup.proxy_value.remote_server
      super
    end

    def define
      remote_task(:create) do |task|
        task.command = cmd "mkdir", "-p", construct_dir
      end
      task :remote_groundwork => self[:create]
    end
  end
end
