require 'mattock/command-task'

module LogicalConstruct
  class SecureCopyFile < Mattock::CommandTask
    nil_fields :destination_address
    nil_fields :source_dir, :destination_dir, :basename
    required_fields :source_path, :destination_path
    runtime_required_field :remote_server
    runtime_required_field :command

    def default_configuration(copy)
      self.remote_server = copy.proxy_value.remote_server
    end

    def resolve_configuration
      super
      self.source_path ||= File::join(source_dir, basename)
      self.destination_path ||= File::join(destination_dir, basename)
    end

    def resolve_runtime_configuration
      self.destination_address ||= [remote_server.address, destination_path].join(":")
      if remote_server.user
        self.destination_address = "#{remote_server.user}@#{destination_address}"
      end
      self.command = cmd("scp",
                         "-o ControlMaster=auto",
                         source_path, destination_address)
    end
  end

  class CopyFiles < Mattock::TaskLib
    default_namespace :copy_files

    required_fields :files_dir, :remote_server, :construct_dir

    setting :files, ["Rakefile", "Gemfile"]

    def default_configuration(setup, build_files)
      super()
      self.files_dir = build_files.target_dir
      self.remote_server = setup.proxy_value.remote_server
      self.construct_dir = setup.construct_dir
    end

    def define
      files.each do |file|
        in_namespace do
          SecureCopyFile.new(self, file) do |task|
            task.runtime_definition do
              task.remote_server = remote_server
            end
            task.source_dir = files_dir
            task.destination_dir = construct_dir
            task.basename = file
          end
        end
        bracket_task(:local_setup, file, :remote_config)
      end

      desc "Copy locally generated files to the remote server"
      task root_task => in_namespace(*files)
      task :remote_config => root_task
    end
  end
end
