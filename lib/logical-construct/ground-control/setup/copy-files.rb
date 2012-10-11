require 'mattock/command-task'

module LogicalConstruct
  class SecureCopyFile < Mattock::CommandTask
    nil_fields :destination_address
    required_fields :source_path, :destination_path
    runtime_required_field :remote_server

    def command
      self.destination_address ||= [remote_server.address, destination_path].join(":")
      cmd("scp", source_path, destination_address)
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

    setting :files, ["Rakefile", "Gemfile"].map do |basename|
      nested(:basename => basename, :source_path => nil, :target_path => nil)
    end

    def default_configuration(setup, build_files)
      super()
      self.files_dir = build_files.target_dir
      self.remote_server = setup.proxy_value.remote_server
      self.construct_dir = setup.construct_dir
    end

    def resolve_configuration
      files.each do |file|
        file.source_path ||= File::join(files_dir, file.basename)
        file.target_path ||= File::join(construct_dir, file.basename)
      end
    end

    def define
      files.each do |file|
        in_namespace do
          SecureCopyFile.new(self, file.basename) do |task|
            task.remote_server = remote_server
            task.source_path = file.source_path
            task.destination_path = file.target_path
          end
        end
        bracket_task(:local_setup, file.basename, :remote_config)
      end

      desc "Copy locally generated files to the remote server"
      task root_task => in_namespace(*files.map(&:basename))
      task :remote_config => root_task
    end
  end
end
