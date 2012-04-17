require 'mattock/tasklib'
require 'mattock/template-host'

module LogicalConstruct
  class ChefConfig < Mattock::Tasklib
    include Mattock::TemplateHost
    default_namespace :chef_config

    required_field :construct_dir
    required_fields :file_cache_path, :cookbook_path, :json_attribs
    required_field :valise
    settings :solo_rb => "/etc/chef/solo.rb",
      :cookbook_relpath => "cookbooks",
      :json_attribs_relpath => "node.json"

    nil_fields :recipe_url, :role_path, :role_relpath

    def default_configuration(provision)
      self.construct_dir = provision.construct_dir
      self.valise = provision.valise
    end

    def resolve_configuration
      if unset?(file_cache_path)
        self.file_cache_path = File::expand_path('chef', construct_dir)
      end

      self.file_cache_path = File::expand_path(file_cache_path)
      if unset?(cookbook_path) and !cookbook_relpath.nil?
        self.cookbook_path = File::expand_path(cookbook_relpath, file_cache_path)
      end

      self.solo_rb = File::expand_path(solo_rb, file_cache_path)

      if unset?(json_attribs) and !json_attribs_relpath.nil?
        self.json_attribs = File::expand_path(json_attribs_relpath, file_cache_path)
      end

      if role_path.nil? and !role_relpath.nil?
        self.role_path = File::expand_path(role_relpath, file_cache_path)
      end
    end

    def define
      in_namespace do
        directory file_cache_path
        directory cookbook_path
        file solo_rb => [file_cache_path, cookbook_path] do
          File::open(solo_rb, "w") do |file|
            file.write(render("chef.rb.erb"))
          end
        end
        unless role_path.nil?
          directory role_path
          file solo_rb => role_path
        end
      end
    end
  end
end
