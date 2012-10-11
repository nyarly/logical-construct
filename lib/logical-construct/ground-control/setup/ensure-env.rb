require 'logical-construct/ground-control/run-on-target'

module LogicalConstruct
  class EnsureEnv < RunOnTarget
    default_namespace :ensure_env

    def define
      remote_task(:bundler, "Ensure that bundler is installed on the remote server") do |task|
        task.verify_command = cmd "bundle", "--version"
        task.command = cmd("sudo") - %w{gem install bundler}
      end
      bracket_task(:local_setup, :bundler, :remote_setup)
    end
  end
end
