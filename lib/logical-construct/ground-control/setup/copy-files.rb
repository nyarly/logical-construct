module LogicalConstruct
  class SecureCopyFile < CommandTask
    nil_fields :destination_address
    required_fields :source_path, :remote_server, :destination_path

    def default_configuration(setup)
      super()
      self.remote_server = setup.remote_server
    end

    def command
      self.destination_address ||= [remote_server.address, destination_path].join(":")
      Mattock::CommandLine.new("scp") do |cmd|
        cmd.options << source_path
        cmd.options << destination_address
      end
    end

    def define
      super
      task :remote_config => self[task_name]
      task self[task_name] => :local_setup
    end
  end

  class CopyFiles < Mattock::TaskLib
    default_namespace :copy_files

    required_fields :files_dir, :remote_server, :construct_dir

    def default_configuration(setup, build_files)
      super()
      self.files_dir = build_files.target_dir
      self.remote_server = setup.remote_server
      self.construct_dir = setup.construct_dir
    end

    def define
      scp_tasks = []
      in_namespace do
        scp_tasks = ["Rakefile", "Gemfile"].map do |basename|
          SecureCopyFile.new(self) do |task|
            task.task_name = basename
            task.remote_server = remote_server
            task.source_path = File::join(files_dir, basename)
            task.destination_path = File::join(construct_dir, basename)
          end.task_name
        end
      end
      desc "Copy locally generated files to the remote server"
      task root_task => in_namespace(*scp_tasks)
      task :remote_config => root_task
    end
  end
end
