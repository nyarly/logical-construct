require 'mattock/command-task'

module LogicalConstruct
  class RemoteCopyFile < Mattock::CommandTask
    nil_fields :destination_address
    nil_fields :source_dir, :destination_dir, :basename
    required_fields :source_path, :destination_path
    runtime_required_field :remote_server
    runtime_required_field :command
    setting :exclude, []

    def default_configuration(copy)
      super
      self.remote_server = copy.proxy_value.remote_server
    end

    def resolve_configuration
      super
      self.source_path ||= File::join(source_dir, basename)
      self.destination_path ||= File::join(destination_dir, basename)
    end

    def secure_shell_command
      escaped_command("ssh") do |ssh|
        ssh.options += RunOnTarget::SSH_OPTIONS.map{|opt| "-o #{opt}"}
        ssh.options << "-l #{remote_server.user}" unless remote_server.user.nil?
      end
    end

    def resolve_runtime_configuration
      self.destination_address ||= [remote_server.address, destination_path].join(":")

      self.command = cmd("rsync") do |rsync|
        rsync.options << "-a"
        rsync.options << "--copy-unsafe-links"
        rsync.options << "-e #{secure_shell_command}"
        exclude.each do |pattern|
          rsync.options << "--exclude #{pattern}"
        end
        rsync.options << source_path
        rsync.options << destination_address
      end
      super
    end
  end

  class CopyFiles < Mattock::TaskLib
    default_namespace :copy_files

    required_fields :files_dir, :remote_server, :construct_dir

    def default_configuration(setup, build_files)
      super()
      self.files_dir = build_files.target_dir
      self.remote_server = setup.proxy_value.remote_server
      self.construct_dir = setup.construct_dir
    end

    def define
      in_namespace do
        RemoteCopyFile.new(self, :construct_dir) do |task|
          task.runtime_definition do
            task.remote_server = remote_server
          end
          task.exclude << "*.so"
          task.exclude << "*.dynlib"
          task.source_path = File::join(files_dir, "*")
          task.destination_path = construct_dir
        end
      end
      bracket_task(:remote_groundwork, :construct_dir, :remote_config)

      desc "Copy locally generated files to the remote server"
      task root_task => in_namespace(:construct_dir)
      task :remote_config => root_task
    end
  end
end
