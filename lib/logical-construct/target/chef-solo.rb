require 'mattock/tasklib'

module LogicalConstruct
  class ChefSolo < Mattock::TaskLib
    default_namespace :chef_solo

    settings(
      :chef_solo_bin => "chef-solo",
      :daemonize => nil,
      :user => nil,
      :group => nil,
      :node_name => nil
    )

    setting :config_file

    def default_configuration(chef_config)
      super
      self.config_file = chef_config.solo_rb
    end

    def define
      in_namespace do
        Mattock::CommandTask.define_task(:run) do |task|
          task.command = Mattock::CommandLine.new(chef_solo_bin) do |cmd|
            cmd.options << "--config #{config_file}" unless config_file.nil?
            cmd.options << "--daemonize" if daemonize
            cmd.options << "--user #{user}" if user
            cmd.options << "--group #{group}" if group
            cmd.options << "--node_name #{node_name}" if node_name
          end
        end
      end
      bracket_task(:build_configs, :run, :provision)
    end
  end
end
