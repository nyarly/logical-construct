module LogicalConstruct
  class BuildAttributes < Mattock::TaskLib
    def default_namespace
      :chef_attributes
    end

    def default_configuration(provision)
      settings(
        :node_attributes => "/etc/chef/node.json",
        :construct_dir => provision.construct_dir
        :attributes_source => nil
      )
    end

    def resolve_configuration
      @attributes_source ||= File::join(construct_dir, "node.yaml")
    end

    def define
      in_namespace do
        file node_attributes => attributes_source do
          attrs = YAML::load(attributes_source)
          render("node.json.erb", attrs)
        end
      end

      task :build_configs => node_attributes
    end
  end
end
