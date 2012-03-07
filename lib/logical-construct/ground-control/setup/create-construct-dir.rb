require 'logical-construct/ground-control/setup/remote'

module LogicalConstruct
  class CreateConstructDirectory < SetupRemoteTask
    default_namespace :construct_directory

    setting(:construct_dir)
    setting(:task_name, :create)

    def default_configuration(setup)
      super
      self.construct_dir = setup.construct_dir
      self.remote_command = Mattock::CommandLine.new("mkdir") do |cmd|
        cmd.options << "-p"
        cmd.options << construct_dir
      end
    end

    def define
      super
      desc "Create #{construct_dir} on the remote server"
      task self[:create]
      task :remote_groundwork => self[:create]
    end
  end
end
