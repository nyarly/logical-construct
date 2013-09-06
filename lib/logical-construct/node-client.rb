require 'roadforest/remote-host'
require 'logical-construct/protocol'

module LogicalConstruct
  class NodeClient
    class ManifestBuilder
      include Protocol::PlanValidation
      def initialize(graph_focus)
        @graph_focus = graph_focus
      end

      def plans_list
        @graph_focus.first_or_add(:lc, "plans").as_list

      end

      def add_plan(plan)
        plans_list.append_node("##{plan.name}") do |node|
          node[[:rdf, "type"  ]] = [:lc, "Need"]
          node[ [:lc, "name"  ]] = plan.name
          node[ [:lc, "digest"]] = file_checksum(plan.archive)
        end
      end
    end

    def initialize
      @plan_archives = []
    end

    attr_accessor :plan_archives, :node_url

    def server
      @server ||= RoadForest::RemoteHost.new(node_url)
    end

    def state
      state = nil
      server.getting do |root|
        state = page_labeled("Current Status", root)[:lc, "node-state"]
      end
      state
    end

    def resolved?
      state.downcase == "resolved"
    end

    def page_labeled(label, focus)
      focus.all(:skos, "hasTopConcept").find do |concept|
        concept.all(:skos, "prefLabel").include?(label) or concept.all(:skos, "altLabel").include?(label)
      end.first(:foaf, "page")
    end

    def deliver_manifest
      server.putting do |root|
        needs = page_labeled("Server Manifest", root)

        builder = ManifestBuilder.new(needs)

        plan_archives.each do |archive|
          builder.add_plan(archive)
        end
      end
    end

    def deliver_plans
      loop do
        needs = []
        server.getting do |root|
          unresolved = page_labeled("Unresolved Needs", root)

          unresolved[:lc, "plans"].as_list.each do |need|
            needs << [need[:lc, "name"], need[:lc, "contents"]]
          end
        end
        break if needs.empty?

        needs.each do |need|
          name, path = *need
          archive = plan_archives.find do |plan|
            plan.name == name
          end

          next if plan.nil?

          File::open(plan.archive, "r") do |file|
            server.put_file(path, file)
          end
        end
      end
    end
  end
end
