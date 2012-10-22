require 'logical-construct/ground-control'
require 'mattock/remote-command-task'

module LogicalConstruct
  class RunOnTarget < Mattock::TaskLib
    include Mattock::CommandLineDSL

    SSH_OPTIONS = [ "ControlMaster=auto", "ControlPersist=3600",
      "StrictHostKeyChecking=no", "UserKnownHostsFile=/dev/null" ]

    runtime_setting(:remote_server)

    def default_configuration(setup)
      super
      self.remote_server = setup.proxy_value.remote_server
    end

    def remote_task(name, comment = nil)
      in_namespace do
        desc comment unless comment.nil?
        Mattock::RemoteCommandTask.new(name) do |task|
          task.ssh_options += SSH_OPTIONS

          task.runtime_definition do |task|
            copy_settings_to(task)
            yield(task)
          end
        end
      end
    end
  end
end
