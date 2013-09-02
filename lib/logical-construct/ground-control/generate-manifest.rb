require 'roadforest/remote-host'
require 'logical-construct/protocol'

module LogicalConstruct
  class GenerateManifest < Mattock::Tasklib
    class ManifestBuilder
      include Protocol::PlanValidation
      def initialize(graph_focus)
        @graph_focus = graph_focus
      end

      def add(plan)
        @graph_focus.as_list.append_node("##{plan.name}") do |node|
          node[[:rdf, "type"]]   = [:lc, "Need"]
          node[ [:lc, "name"]]   = plan.name
          node[ [:lc, "digest"]] = file_checksum(plan.archive)
        end
      end
    end

    default_namespace :manifest

    setting :plan_archives, []
    setting :graph_format, :jsonld
    setting :target_address

    def default_configuration(provision)
      super
      self.plan_archives = provision.proxy_value.plan_archives
      self.target_address = provision.proxy_value.target_address
    end

    def define
      in_namespace do
        desc "Dump manifest (mostly for debugging)"
        task :dump, [:format] do |task, args|
          require 'rdf/turtle'
          format = args[:format] || graph_format
          format = format.to_sym

          base_url = "urn:manifest"

          graph = ::RDF::Graph.new
          focus = RoadForest::RDF::GraphFocus.new(base_url, graph)
          builder = ManifestBuilder.new(focus)

          plan_archives.each do |archive|
            builder.add(archive)
          end

          puts(RDF::Writer.for(format).buffer(:base_uri => base_url) do |writer|
            focus.relevant_prefixes.each do |prefix, uri|
              writer.prefix(prefix, uri)
            end
            writer.insert(graph)
          end)
        end

        task :deliver do |task|
          node = RoadForest::RemoteHost.new(node_url)
          node.putting do |root|
            needs = root.all(:skos, "hasTopConcept").find do |concept|
              concept[:skos, "label"] = "Needs"
            end.first(:foaf, "page")

            builder = ManifestBuilder.new(needs)
            plan_archives.each do |archive|
              builder.add(archive)
            end
          end
        end
      end
      task self[:dump] => root_task
      task self[:deliver] => root_task
    end
  end
end
