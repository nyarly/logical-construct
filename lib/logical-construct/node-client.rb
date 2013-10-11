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
        @graph_focus.find_or_add([:lc, "plans"]).as_list
      end

      def add_plan(plan_archive)
        name = File::basename(plan_archive)
        plans_list.append_node("##{name}") do |node|
          node[[:rdf, "type"  ]] = [:lc, "Need"]
          node[[ :lc, "name"  ]] = name
          node[[ :lc, "digest"]] = file_checksum(plan_archive)
        end
      end
    end

    def initialize
      @plan_archives = []
      @silent = false
    end

    attr_accessor :plan_archives, :node_url, :server, :silent

    def server
      @server ||= RoadForest::RemoteHost.new(node_url).tap do |server|
        #server.graph_transfer.trace = true
      end
    end

    def report(item)
      puts item unless silent
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
      concept = focus.all(:skos, "hasTopConcept").find do |concept|
        concept.all(:skos, "prefLabel").include?(label) or concept.all(:skos, "altLabel").include?(label)
      end
      concept.first(:foaf, "page")
    end

    def deliver_manifest
      report "Delivering manifest"
      messages = []
      server.putting do |root|
        messages = []
        needs = page_labeled("Server Manifest", root)

        builder = ManifestBuilder.new(needs)

        plan_archives.each do |archive|
          messages << "Adding #{archive}"
          builder.add_plan(archive)
        end
      end
      report messages
    end

    def deliver_plans
      loop do
        needs = []
        server.getting do |root|
          needs = []
          unresolved = page_labeled("Unresolved Plans", root)

          unresolved[:lc, "plans"].as_list.each do |need|
            needs << [need[:lc, "name"], need[:lc, "contents"]]
          end
        end
        if needs.empty?
          report "Target needs fulfilled"
          break
        end

        report "Delivering plan archives"
        needs.each do |need|
          name, path = *need
          plan = plan_archives.find do |plan|
            File.basename(plan) == name
          end

          next if plan.nil?

          File::open(plan, "r") do |file|
            report " Delivering #{name}"
            server.put_file(path, "application/x-gtar-compressed", file) #sorta like a ukulele
          end
        end
      end
    end
  end
end
