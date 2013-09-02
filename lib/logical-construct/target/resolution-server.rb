require 'rdf/vocab/skos'
require 'logical-construct/protocol'
require 'logical-construct/target/plan-records'

module LogicalConstruct
  module ResolutionServer
    class Application < RoadForest::Application
      def setup
        router.add  :root,              [],                    :read_only,  Models::Navigation
        router.add  :unresolved_plans,  ["unresolved_plans"],  :parent,     Models::UnresolvedPlansList
        router.add  :full_plans,        ["full_plans"],        :parent,     Models::FullPlansList
        router.add  :plan,              ["plans",'*'],         :leaf,       Models::Plan
        router.add  :file_content,      ["files","*"],         :leaf,       Models::PlanContent
      end
    end

    class ServicesHost < ::RoadForest::Application::ServicesHost
      attr_accessor :plan_records

      def initialize
        @plan_records = PlanRecords.new
      end

      def destination_dir
        plan_records.directories.delivery
      end
    end

    module Models
      class Navigation < RoadForest::RDFModel
        def exists?
          true
        end

        def update(graph)
          return false
        end

        def nav_entry(graph, name, path)
          graph.add_node([:skos, :hasTopConcept], "#" + name) do |entry|
            entry[:rdf, :type] = [:skos, "Concept"]
            entry[:skos, :label] = name
            entry[:foaf, "page"] = path
          end
        end

        def fill_graph(graph)
          graph[:rdf, "type"] = [:skos, "ConceptScheme"]
          nav_entry(graph, "Unresolved Plans", path_for(:unresolved_plans))
          nav_entry(graph, "All Plans", path_for(:unresolved_plans))
        end
      end


      class PlansList < RoadForest::RDFModel
        def exists?
          true
        end

        def update(graph)
        end

        def add_child(graph)
          record = services.plan_records.add(graph.first(:lc, "name"), graph.first(:lc, "hash"))
          record.resolve
        end

        def plan_records
          services.plan_records
        end

        def fill_graph(graph)
          graph.add_list(:lc, "plans") do |list|
            plan_records.each do |record|
              list << path_for(:plan, '*' => record.name)
            end
          end
        end
      end

      class UnresolvedPlansList < PlansList
        def plan_records
          #recheck resolution?
          services.plan_records.find_all{|record| !record.resolved}
        end
      end

      class FullPlansList < PlansList
        def update(graph)
          services.plan_records.reset

          graph.as_list.each do |plan|
            add_child(plan)
          end
        end
      end

      class PlanContent < RoadForest::BlobModel
        add_type "text/plain", TypeHandlers::Handler.new
        add_type "application/octet-stream", TypeHandlers::Handler.new

        def update(file)
          name = params.remainder
          record = services.plan_records.find(name)
          raise "Unexpected file: #{name}" if record.nil?
          raise "Plan already resolved: #{name}" unless record.can_receive?

          super(file)

          record.receive
        end
      end

      class Plan < RoadForest::RDFModel
        def data
          @data = services.plan_records.find do |record|
            record.name == params.remainder
          end
        end

        def fill_graph(graph)
          graph[[:lc, "name"]] = data.name
          graph[[:lc, "hash"]] = data.filehash
          graph[[:lc, "contents"]] = path_for(:file_content)
        end
      end
    end
  end
end
