require 'logical-construct/ground-control/run-on-target'

module LogicalConstruct
  class BundleSetup < RunOnTarget
    default_namespace :bundle_setup

    setting :construct_dir
    nil_fields :bundle_path, :bin_path

    def default_configuration(setup)
      setup.copy_settings_to(self)
      super
    end

    def resolve_configuration
      self.bundle_path ||= File.join(construct_dir, "lib")
      self.bin_path ||= File.join(construct_dir, "bin")
    end

    def remote_command
      Mattock::PrereqChain.new do |cmd|
        cmd.add Mattock::CommandLine.new("cd", construct_dir)
        cmd.add Mattock::CommandLine.new("bundle") do |cmd|
        end
      end
    end

    def define
      remote_task(:run, "Set up bundle on the remote server") do |task|
        task.command = (cmd("cd", construct_dir) &
          ["bundle", "--path #{bundle_path}", "--binstubs #{bin_path}"]).tap{|cl| p cl}
      end
      bracket_task(:remote_config, :run, :remote_setup)
    end
  end
end
