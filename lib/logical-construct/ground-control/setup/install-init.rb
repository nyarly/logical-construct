require 'mattock'
require 'logical-construct/ground-control/run-on-target'

module LogicalConstruct
  module GroundControl
    class InstallInit < RunOnTarget
      required_fields :source_path, :target_path
      setting :construct_dir
      setting :service_name, "logical-construct"
      setting :initd_path, "/etc/init.d"

      def default_configuration(setup)
        super
        setup.copy_settings_to(self)
      end

      def resolve_configuration
        super
        self.source_path ||= File::join(construct_dir, "construct.init.d")
        self.target_path ||= File::join(initd_path, service_name)
      end

      def define
        remote_task(:install_init) do |task|
          task.command = cmd("install", "-T", source_path, target_path) &
            ["rc-update", "add", service_name, "default"]
        end
        bracket_task(:remote_config, :install_init, :remote_setup)
      end
    end
  end
end
