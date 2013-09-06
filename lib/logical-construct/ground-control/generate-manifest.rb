require 'logical-construct/node-client'

module LogicalConstruct
  class GenerateManifest < Mattock::Tasklib
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
          builder = NodeClient::ManifestBuilder.new(focus)

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
          client = NodeClient.new
          client.node_url = node_url
          client.plan_archives = plan_archives
          client.deliver_manifest
        end

        task :fulfill do |task|

        end
      end
      task self[:dump] => root_task
      task self[:deliver] => root_task
    end
  end
end
