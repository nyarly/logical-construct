require 'logical-construct/target/sinatra-resolver'
module LogicalConstruct
  module Default
    class ResolveConfiguration < Mattock::Tasklib
      default_namespace 'configuration'

      setting :bind, '0.0.0.0'
      setting :port, 51076
      setting :valise

      def initialize(*args, &block)
        @pending_satisfiables = []
        @resolver = nil
        @manifest = nil
        super
      end

      def default_configuration(provision)
        super
        self.valise = provision.valise
      end

      def add_file(file_satisfiable)
        if @resolver.nil?
          @pending_satifiables << file_satisfiable
        else
          @resolver.add_satisfiable(file_satisfiable)
          @manifest.add_satisfiable(file_satisfiable)
        end
      end

      def define
        in_namespace do
          @manifest = LogicalConstruct::Manifest.new(*@pending_satisfiables)

          @resolver = LogicalConstruct::SinatraResolver.new(*([@manifest] + @pending_satisfiables)) do |task|
            copy_settings_to(task)
          end
          @pending_satisfiables.clear
        end
      end
    end
  end
end
