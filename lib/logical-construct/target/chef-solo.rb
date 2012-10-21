require 'mattock/tasklib'

module LogicalConstruct
  class ChefSolo < Mattock::TaskLib
    default_namespace :chef_solo

    settings(
      :chef_solo_bin => "chef-solo",
      :config_dir => "/etc/chef",
      :config_file_relpath => "solo.rb",
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

    def resolve_configuration
      super
      self.config_file ||= File::join(config_dir, config_file_relpath)
    end

    def chef_command
      Mattock::CommandLine.new(chef_solo_bin) do |cmd|
        cmd.options << "--config #{config_file}" unless config_file.nil?
        cmd.options << "--daemonize" if daemonize
        cmd.options << "--user #{user}" if user
        cmd.options << "--group #{group}" if group
        cmd.options << "--node_name #{node_name}" if node_name
      end
    end

    def define
      in_namespace do
        directory config_dir
        file config_file => config_dir

        task :run => [config_file] do
          chef_command.run
        end
      end
      task :provision => self[:run]
    end
  end
end
