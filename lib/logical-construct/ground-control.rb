require 'mattock'

module LogicalConstruct
  class GroundControl < Mattock::TaskLib
    include Mattock::ValiseManager

    default_namespace :parent
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

require 'logical-construct/parent/setup'
#require 'logical-construct/parent/launch'
