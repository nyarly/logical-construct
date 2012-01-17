module LogicalConstruct
  class ChefSolo < Mattock::TaskLib
    def default_namespace
      :chef_solo
    end

    def default_configuration(build)
      settings(
        :chef_solo_bin => "chef-solo",
        :config_file => "/etc/chef/solo.rb",
        :daemonize => nil,
        :user => nil,
        :group => nil,
        :json_attributes => build.node_attributes,
        :node_name => nil
      )
    end

    def chef_command
      Mattock::CommandLine.new(chef_solo_bin) do |cmd|
        cmd.options << "--config #{config_file}"
        cmd.options << "--json_attrbutes #{json_attributes}"
        cmd.options << "--daemonize" if daemonize
        cmd.options << "--user #{user}" if user
        cmd.options << "--group #{group}" if group
        cmd.options << "--node_name #{node_name}" if node_name
      end
    end

    def define
      in_namespace do
        file config_file
        task :run => [config_file, json_attributes] do
          chef_command.run
        end
      end
      task :provision => self[:run]
    end
  end
end
