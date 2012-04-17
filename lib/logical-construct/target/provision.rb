require 'mattock'
require 'mattock/template-host'

module LogicalConstruct
  class Provision < Mattock::Tasklib
    include Mattock::ValiseManager
    extend Mattock::ValiseManager

    settings(
      :construct_dir => "/var/logical-construct",
      :attr_source => nil,
      :config_path => nil
    )
    setting :valise
    setting :search_paths, [rel_dir(__FILE__)]

    def resolve_configuration
      self.valise = default_valise(search_paths)
      super
    end

    def define
      task :preflight

      task :approve_host => :preflight

      task :build_configs => :approve_host

      task :provision => :build_configs
    end
  end
end
