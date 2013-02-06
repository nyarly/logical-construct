require 'logical-construct/target/platforms/incapable-tasklib'

module LogicalConstruct
  module Default
    class Bake < IncapableTasklib
      default_namespace :bake

      def define
        super
        cant_do(:begin, :run)
      end
    end

    class BakeSystem < IncapableTasklib
      default_namespace :system #assumed to be within a :bake NS

      def define
        super
      end
    end
  end
end
