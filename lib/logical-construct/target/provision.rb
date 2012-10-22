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
    setting :construct_bin_path
    setting :search_paths, [rel_dir(__FILE__)]

    def resolve_configuration
      self.valise = default_valise(search_paths)
      self.construct_bin_path ||= File::expand_path("bin", construct_dir)
      self.construct_bin_path = File::absolute_path(construct_bin_path)
      super
    end

    def define
      task_spine(:preflight, :approve_host, :build_configs, :provision)

      task :bundled_path do
        unless ENV['PATH'] =~ /(?:^|:)#{construct_bin_path}(?::|$)/
          ENV['PATH'] = "#{construct_bin_path}:#{ENV['PATH']}"
        end
      end
      task :preflight => :bundled_path
    end
  end
end
