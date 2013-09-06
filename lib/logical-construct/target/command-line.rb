require 'logical-construct/target/flight-control'

module LogicalConstruct
  module Target
    class CommandLine < ::Rake::Application
      def initialize
      end

      def go
        init(File::basename($0))
        FlightControl.new
        top_level
      end
    end
  end
end
