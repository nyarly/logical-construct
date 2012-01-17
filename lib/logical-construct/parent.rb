require 'mattock'

module LogicalConstruct
  class Parent < Mattock::TaskLib
    include Mattock::ValiseManager

    default_namespace :parent
    setting(:search_paths, [Mattock::ValiseManager.rel_dir(__FILE__)])
    setting(:valise)

    def default_configuration
      super
    end

    def resolve_configuration
      @valise = default_valise(search_paths)
      super
    end
  end
end

module LogicalConstruct
  class Setup < Mattock::TaskLib

    default_namespace :setup

    settings(
      :remote_server => nested( :address => nil, :user => nil),
      :construct_dir => "/var/logical-construct",
    )

    def define
      in_namespace do
        task :collect, [:address] do |t, args|
          @remote_server.address = args[:address]
        end

        task :local_setup => [:collect]

        task :remote_groundwork => [:local_setup]

        task :remote_config => [:remote_groundwork]

        task :remote_setup => [:remote_config]

        task :complete => [:local_setup, :remote_setup]
      end

      desc "Set up a remote server to act as a Construct foundation"
      task root_task,[:address] => self[:complete]
    end
  end
end

module LogicalConstruct
  class CommandTask < Mattock::TaskLib
    setting(:task_name, :run)

    def command_task
      @command_task ||=
        begin
          task task_name do
            do_this = command
            do_this.run
            do_this.must_succeed!
          end
        end
    end

    def define
      in_namespace do
        command_task
      end
    end
  end

  class RemoteCommandTask < CommandTask
    setting(:remote_server, nested(
      :address => nil,
      :user => nil
    ))
    setting(:ssh_options, [])
    setting(:remote_command)
    nil_fields(:id_file, :free_arguments)

    def command(command_on_remote = nil)
      fail "Need remote server for #{self.class.name}" unless remote_server.address

      command_on_remote ||= remote_command

      raise "Empty remote command" if command_on_remote.nil?
      Mattock::WrappingChain.new do |cmd|
        cmd.add Mattock::CommandLine.new("ssh") do |cmd|
          cmd.options << "-u #{remote_server.user}" if remote_server.user
          cmd.options << "-i #{id_file}" if id_file
          unless ssh_options.empty?
            ssh_options.each do |opt|
              cmd.options "-o #{opt}"
            end
          end
          cmd.options << remote_server.address
        end
        cmd.add Mattock::ShellEscaped.new(command_on_remote)
      end
    end
  end

  class VerifiableCommandTask < RemoteCommandTask
    setting(:verify_command, nil)

    def verify_command
      if @verify_command.respond_to?(:call)
        @verify_command = @verify_command.call
      end
      @verify_command
    end

    def define
      super

      definer = self
      (class << command_task; self; end).instance_eval do
        define_method :needed? do
          !definer.command(definer.verify_command).succeeds?
        end
      end
    end
  end

  class SetupRemoteTask < RemoteCommandTask
    def default_configuration(setup)
      super()
      @remote_server = setup.remote_server
    end
  end

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

  class ConfigBuilder < Mattock::TaskLib
    include Mattock::TemplateHost

    setting(:source_path, nil)
    setting(:target_path, nil)

    setting(:valise)
    setting(:target_dir)

    setting(:base_name)
    setting(:extra, {})

    def default_configuration(host)
      super
      self.target_dir = host.target_dir
      self.valise = host.valise
    end

    def resolve_configuration
      self.target_path ||= File::join(target_dir, base_name)
      self.source_path ||= "#{base_name}.erb"
      super
    end

    def define
      in_namespace do
        file target_path => [target_dir, valise.find("templates/" + source_path).full_path, Rake.application.rakefile] do
          File::open(target_path, "w") do |file|
            file.write render(source_path)
          end
        end
      end
      task :local_setup => target_path
    end
  end

  class BuildFiles < Mattock::TaskLib
    default_namespace :build_files

    setting(:target_dir, "target_configs")
    setting(:valise)

    def default_configuration(parent)
      super
      self.valise = parent.valise
    end

    attr_reader :built_files

    def define
      file_tasks = []
      in_namespace do
        directory target_dir

        file_tasks = ["Rakefile", "Gemfile"].map do |path|
          ConfigBuilder.new(self) do |task|
            task.base_name = path
          end
        end
      end
      desc "Template files to be created on the remote server"
      task root_task => file_tasks.map{|t| t.target_path}
      task :local_setup => root_task
    end
  end

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

  class BundleSetup < SetupRemoteTask
    default_namespace :bundle_setup

    setting :construct_dir
    nil_fields :bundle_path, :bin_path

    def default_configuration(setup)
      super
      self.construct_dir = setup.construct_dir
    end

    def resolve_configuration
      self.bundle_path ||= File.join(construct_dir, "lib")
      self.bin_path ||= File.join(construct_dir, "bin")
    end

    def remote_command
      Mattock::PrereqChain.new do |cmd|
        cmd.add Mattock::CommandLine.new("cd", construct_dir)
        cmd.add Mattock::CommandLine.new("bundle") do |cmd|
          cmd.options << "--path #{bundle_path}"
          cmd.options << "--binstubs #{bin_path}"
        end
      end
    end

    def define
      desc "Set up bundle on the remote server"
      super
      task :remote_setup => self[task_name]
      task self[task_name] => :remote_config
    end
  end
end
