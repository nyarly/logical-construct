module LogicalConstruct
  class EnsureEnv < Mattock::TaskLib
    default_namespace :ensure_env

    setting(:remote_server)

    def default_configuration(setup)
      super
      self.remote_server = setup.remote_server
    end

    def define
      in_namespace do
        desc "Ensure that bundler is installed on the remote server"
        VerifiableCommandTask.new do |task|
          task.remote_server = remote_server
          task.task_name = :bundler
          task.verify_command = Mattock::CommandLine.new("bundle", "--version")
          task.remote_command = Mattock::WrappingChain.new do |chain|
            chain.add Mattock::CommandLine.new("sudo")
            chain.add Mattock::CommandLine.new("gem", "install", "bundler")
          end
        end
      end
      task self[:bundler] => :local_setup
      task :remote_setup => self[:bundler]
    end
  end
end
