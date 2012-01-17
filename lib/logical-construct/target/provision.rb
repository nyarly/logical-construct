require 'mattock'

module LogicalConstruct
  class Provision < Mattock::Tasklib
    def default_configuration
      settings(
        :construct_dir => "/var/logical-construct"
        :attr_source => nil,
        :cookbook_path => nil,
        :config_path => nil
      )

    end


    def define
      task :preflight

      task :build_configs => :preflight

      task :provision => :build_configs
    end
  end
end
