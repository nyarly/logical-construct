require 'logical-construct/ground-control/setup/remote'

module LogicalConstruct
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
