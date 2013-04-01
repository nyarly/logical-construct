require 'socket'
require 'mattock'
require 'mattock/command-task'

module LogicalConstruct
  class SSHTunnel < Mattock::Tasklib
    class CreateTask < Mattock::Rake::CommandTask
      default_taskname :create

      runtime_setting :tunnel_created, false
      setting :target_address

      setting :target_port, 10000
      setting :local_target_port
      setting :remote_target_port

      def seek_open_port
        test_server = TCPServer.new("0.0.0.0", remote_target_port)
      rescue Errno::EADDRINUSE
        self.remote_target_port += 1
        retry
      ensure
        test_server.close
      end

      def resolve_configuration
        super
        self.local_target_port ||= target_port
        self.remote_target_port ||= target_port
        self.command = cmd("ssh", "-n", "-o ControlMaster=auto", "-o ExitOnForwardFailure=yes",
                           "-L", "localhost:#{local_target_port}:localhost:#{remote_target_port}", target_address)
      end

      def already_created
        p :testing_created
        cmd("ssh", "-o ControlMaster=auto", "-O check", target_address).succeeds?
      end

      def action
        seek_open_port
        unless already_created
          self.tunnel_created = true
        end
        p :create_created? => tunnel_created
        p self
        super
      rescue StandardError => se
        puts "Attempting to recover from: #{se.message}"
        retry
      end

    end

    class CancelTask < Mattock::Rake::CommandTask
      default_taskname :cancel

      setting :target_address

      def resolve_configuration
        super
        self.command = cmd("ssh", "-n", "-o ControlMaster=auto", "-O exit", target_address)
      end
    end

    class CleanupTask < Mattock::Rake::Task
      default_taskname :cleanup

      runtime_setting :tunnel_created, false
      setting :cancel_taskname

      def needed?
        p self
        p :created => tunnel_created
        return !!tunnel_created
      end

      def action
        Rake::Task[cancel_taskname].invoke
      end
    end

    default_namespace :ssh_tunnel

    runtime_setting :target_address
    setting :target_port, 10000

    def wrap(task_name)
      task task_name => self[:create]
      task self[:cleanup] => task_name
    end

    def define
      in_namespace do
        create = CreateTask.define_task(self) do |create|
          copy_settings_to(create)
        end

        desc "Close an existing SSH tunnel"
        CancelTask.define_task(self) do |cancel|
          copy_settings_to(cancel)
        end

        CleanupTask.define_task do |cleanup|
          cleanup.tunnel_created = create.proxy_value.tunnel_created
          cleanup.cancel_taskname = self[:cancel]
        end

        desc "Open an SSH tunnel to the target address"
        task :run => [:create, :cleanup]
      end
    end
  end
end
