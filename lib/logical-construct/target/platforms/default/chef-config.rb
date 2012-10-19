require 'mattock/tasklib'
require 'mattock/template-host'
require 'logical-construct/satisfiable-task'

module LogicalConstruct
  module Default
    class ChefConfig < Mattock::Tasklib
      include Mattock::TemplateHost
      default_namespace :chef_config

      required_field :construct_dir
      required_fields :file_cache_path, :cookbook_path, :cookbook_tarball_path, :json_attribs
      required_field :valise
      settings :solo_rb => "/etc/chef/solo.rb",
        :cookbook_relpath => "cookbooks",
        :cookbook_tarball_relpath => "cookbooks.tgz",
        :json_attribs_relpath => "node.json"

      setting :resolution_task

      nil_fields :recipe_url, :role_path, :role_relpath

      def default_configuration(provision, resolution)
        super
        self.construct_dir = provision.construct_dir
        self.valise = provision.valise
        self.resolution_task = resolution[:resolve]
      end

      def resolve_configuration
        if unset?(file_cache_path)
          self.file_cache_path = File::expand_path('chef', construct_dir)
        end

        self.file_cache_path = File::expand_path(file_cache_path)
        if unset?(cookbook_path) and !cookbook_relpath.nil?
          self.cookbook_path = File::expand_path(cookbook_relpath, file_cache_path)
        end

        if unset?(cookbook_tarball_path) and !cookbook_tarball_relpath.nil?
          self.cookbook_tarball_path = File::expand_path(cookbook_tarball_relpath, file_cache_path)
        end

        self.solo_rb = File::expand_path(solo_rb, file_cache_path)

        if unset?(json_attribs) and !json_attribs_relpath.nil?
          self.json_attribs = File::expand_path(json_attribs_relpath, file_cache_path)
        end

        if role_path.nil? and !role_relpath.nil?
          self.role_path = File::expand_path(role_relpath, file_cache_path)
        end
        super
      end

      include Mattock::CommandLineDSL
      def define
        in_namespace do
          directory file_cache_path

          Mattock::CommandTask.new(:unpack_cookbooks => resolution_task) do |task|
            task.command = cmd("cd", file_cache_path) & cmd("tar", "-xzf", cookbook_tarball_path)
          end

          file solo_rb => [file_cache_path, resolution_task, :unpack_cookbooks] do
            File::open(solo_rb, "w") do |file|
              file.write(render("chef.rb.erb"))
            end
          end

          SatisfiableFileTask.new(:json_attribs => file_cache_path) do |task|
            task.target_path = json_attribs
          end

          SatisfiableFileTask.new(:cookbook_tarball => file_cache_path) do |task|
            task.target_path = cookbook_tarball_path
          end

          unless role_path.nil?
            directory role_path
            file solo_rb => role_path
          end
        end

        task resolution_task => self[:json_attribs]
        task resolution_task => self[:cookbook_tarball]
      end
    end
  end
end
