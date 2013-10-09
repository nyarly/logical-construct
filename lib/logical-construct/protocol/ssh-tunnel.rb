require 'socket'
require 'mattock'
require 'mattock/command-task'

module LogicalConstruct
  class SSHTunnel < Mattock::Tasklib
    class OpenPortTask < Mattock::Rake::Task
      default_taskname :open_port
      setting :base_port
      setting :found_port

      def resolve_configuration
        self.found_port = base_port
        super
      end

      def configure_discovery(base_port)
        self.base_port = base_port
        return proxy_value.found_port
      end

      def action(args)
      test_server = TCPServer.new("0.0.0.0", found_port)
      rescue Errno::EADDRINUSE
        self.found_port += 1
        retry
      ensure
        test_server.close
      end
    end

    class CreateSSHMaster < Mattock::Rake::CommandTask
      default_taskname :create_ssh_master

      setting :target_address

      def verify_command
        cmd("ssh", "-o ControlMaster=auto", "-O check", target_address)
      end

      def command
        cmd("ssh", "-Nf", "-o ControlMaster=auto", "-o ControlPersist=300", "-o ExitOnForwardFailure=yes", target_address)
      end

      def action(args)
        super
      rescue StandardError => se
        puts "Attempting to recover from: #{se.message}"
        retry
      end
    end

    class CreateTunnel < Mattock::Rake::CommandTask
      default_taskname :create_tunnel

      setting :target_address
      setting :local_target_port
      setting :remote_target_port

      def command
        cmd("ssh", "-O", "forward", "-L", "localhost:#{local_target_port}:localhost:#{remote_target_port}", target_address)
      end
    end

    class CancelTask < Mattock::Rake::CommandTask
      default_taskname :cancel_tunnel

      setting :target_address

      def verify_command
        cmd("ssh", "-o ControlMaster=auto", "-O check", target_address)
      end

      def check_verification_command
        !super
      end

      def command
        cmd("ssh", "-n", "-o ControlMaster=auto", "-O exit", target_address)
      end
    end

    default_namespace :ssh_tunnel

    runtime_setting :target_address
    setting :target_port, 10000
    setting :local_target_port
    setting :remote_target_port

    def resolve_configuration
      self.local_target_port ||= target_port
      self.remote_target_port ||= target_port
      super
    end

    def wrap(task_name)
      task task_name => self[:create_tunnel]
      task self[:cancel_tunnel] => task_name
    end

    def define
      in_namespace do
        open_port = OpenPortTask.define_task do |open_port|
          self.local_target_port = open_port.configure_discovery(local_target_port)
        end

        master = CreateSSHMaster.define_task(self) do |master|
          copy_settings_to(master)
        end

        create = CreateTunnel.define_task(self) do |create|
          copy_settings_to(create)
        end

        cancel = CancelTask.define_task(self) do |cancel|
          copy_settings_to(cancel)
        end

        task_spine create.task_name, :close_tunnel, :run

        task master.task_name => open_port.task_name
        task create.task_name => master.task_name
        task :close_tunnel => cancel.task_name
      end
    end
  end
end
