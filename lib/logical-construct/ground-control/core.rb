require 'mattock'

module LogicalConstruct
  module GroundControl
    class Core < Mattock::TaskLib
      include Mattock::ValiseManager

      default_namespace :core
      setting(:search_paths, [Mattock::ValiseManager.rel_dir(__FILE__)])
      setting(:valise)

      def default_configuration
        super
      end

      def resolve_configuration
        @valise = default_valise(search_paths)
        super
      end
    end
  end
end
