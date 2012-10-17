p :loading => __FILE__
require 'mattock'

module LogicalConstruct
  module GroundControl
    class Core < Mattock::TaskLib
      include Mattock::ValiseManager
      extend Mattock::ValiseManager

      default_namespace :core
      setting(:search_paths, [rel_dir(__FILE__)])
      setting(:valise)

      def default_configuration
        super
      end

      def resolve_configuration
        self.valise = default_valise(*search_paths)
        super
      end

      def define
        in_namespace do
          desc "List the search paths for files used by ground control"
          task :search_paths do
            p valise
          end
        end
      end
    end
  end
end
