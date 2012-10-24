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
        remote_task(:copy_init) do |task|
          task.command = cmd("mv", source_path, target_path)
        end
        remote_task({:rc_update => :copy_init}) do |task|
          task.command = cmd("rc-update", "add", service_name, "default")
        end
        task :remote_setup => self[:rc_update]
        task self[:rc_update] => :remote_config
      end
    end
  end
end
