require 'logical-construct/target/flight-deck'

module LogicalConstruct
  module Target
    class CommandLine < ::Rake::Application
      def initialize(argv)
        @argv = argv
        @manifest_path = nil
        @flight_deck_tasks = []
        @plan_options = []
        super()
      end

      def go
        init(File::basename($0))
        Rake.application = self
        FlightDeck.new do |control|
          control.namespace_name = nil
          control.top_level_tasks = @implement_tasks
          control.manifest_path = @manifest_path
          control.plan_options = @plan_options
        end
        top_level
      end

      def collect_tasks
        super
        @implement_tasks = @top_level_tasks
        @top_level_tasks = @flight_deck_tasks
        if @top_level_tasks.empty?
          @top_level_tasks = ['implement']
        end
      end

      def mutate_options(patterns, options, &block)
        patterns.each do |switch|
          option = options.find{|list| /^#{switch}/ =~ list[0]}
          next if option.nil?
          previous_handler = option.pop
          option.push lambda{|value| yield(switch, previous_handler, value)}
          lambda{|value| @plan_options << "#{switch}=#{value}"}
        end
        options
      end

      def collect_plan_option(name, value)
        if value == true or value.nil? or value.empty?
          @plan_options << name
        else
          @plan_options << "#{name}=#{value}"
        end
      end

      def forward_to_plans(options)
        patterns = %w{--prereqs}
        new_options = []
        patterns.each do |switch|
          option = options.find{|list| /^#{switch}/ =~ list[0]}
          next if option.nil?
          new_options << [option[0].sub(/^--/, "--flight-deck-"), option[-2], option[-1]]
        end

        new_options + mutate_options(patterns, options) do |switch, previous_handler, value|
          collect_plan_option(switch, value)
        end
      end

      def mirror_to_plans(options)
        mutate_options(%w{--trace}, options) do |switch, previous_handler, value|
          previous_handler[value]
          collect_plan_option(switch, value)
        end
      end

      def add_options(options)
        return options + [
          [ "--control-task", "-C TASK",
            "Alter the tasks run by flight-deck itself (rather than task run by the plans)",
            lambda{|value| @flight_deck_tasks << value} ],
            [ "--manifest-file", "-M MANIFEST",
              "Supply a starting server manifest (gotten from e.g. AWS userdata)",
              lambda{|value| @manifest_path = value } ] ]
      end

      def standard_rake_options
        sort_options( add_options( forward_to_plans( mirror_to_plans( super))))
      end
    end
  end
end
