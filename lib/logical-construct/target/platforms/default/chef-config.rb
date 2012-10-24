require 'mattock/tasklib'
require 'mattock/template-host'
require 'mattock/command-line'
require 'logical-construct/satisfiable-task'

module LogicalConstruct
  module Default
    #XXX Should get broken into at least 2 smaller tasklibs
    class ChefConfig < Mattock::Tasklib
      include Mattock::TemplateHost
      default_namespace :chef_config

      required_field :construct_dir
      required_fields :cookbook_path, :data_bags_path, :json_attribs,
        :cookbook_tarball_path, :file_cache_path, :secret_data_tarball_path, :normal_data_tarball_path
      required_field :valise
      settings :solo_rb => "/etc/chef/solo.rb",
        :etc_chef => "/etc/chef",
        :data_bags_relpath => "data_bags",
        :cookbook_relpath => "cookbooks",
        :cookbook_tarball_relpath => "cookbooks.tgz",
        :secret_data_tarball_relpath => "secret_data.tgz",
        :normal_data_tarball_relpath => "normal_data.tgz",
        :json_attribs_relpath => "node.json"

      setting :resolution

      nil_fields :recipe_url, :role_path, :role_relpath

      def default_configuration(provision, resolution)
        super
        self.construct_dir = provision.construct_dir
        self.valise = provision.valise
        self.resolution = resolution
      end

      #XXX Hints about decomposing this Tasklib: there are settings for
      #chef/solo.rb, which are only incidentally related to the tarball
      #unpacking tasks - which are themselves closely related
      def resolve_configuration
        if unset?(file_cache_path)
          self.file_cache_path = File::expand_path('chef', construct_dir)
        end
        self.file_cache_path = File::expand_path(file_cache_path)

        if unset?(cookbook_path) and !cookbook_relpath.nil?
          self.cookbook_path = File::expand_path(cookbook_relpath, file_cache_path)
        end

        if unset?(data_bags_path) and !data_bags_relpath.nil?
          self.data_bags_path = File::expand_path(data_bags_relpath, file_cache_path)
        end

        if unset?(cookbook_tarball_path) and !cookbook_tarball_relpath.nil?
          self.cookbook_tarball_path = File::expand_path(cookbook_tarball_relpath, file_cache_path)
        end

        if unset?(secret_data_tarball_path) and !secret_data_tarball_relpath.nil?
          self.secret_data_tarball_path = File::expand_path(secret_data_tarball_relpath, file_cache_path)
        end

        if unset?(normal_data_tarball_path) and !normal_data_tarball_relpath.nil?
          self.normal_data_tarball_path = File::expand_path(normal_data_tarball_relpath, file_cache_path)
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
          directory etc_chef
          directory file_cache_path

          Mattock::CommandTask.new(:unpack_cookbooks => :cookbook_tarball) do |task|
            task.command = cmd("cd", file_cache_path) & cmd("tar", "-xzf", cookbook_tarball_path)
          end

          Mattock::CommandTask.new(:unpack_secret_data => :secret_data_tarball) do |task|
            task.command = cmd("cd", file_cache_path) & cmd("tar", "-xzf", secret_data_tarball_path)
          end

          Mattock::CommandTask.new(:unpack_normal_data => :normal_data_tarball) do |task|
            task.command = cmd("cd", file_cache_path) & cmd("tar", "-xzf", normal_data_tarball_path)
          end

          file solo_rb => [etc_chef, :json_attribs, :unpack_cookbooks] do
            File::open(solo_rb, "w") do |file|
              file.write(render("chef.rb.erb"))
            end
          end

          resolution.add_file(SatisfiableFileTask.new(:json_attribs => file_cache_path) do |task|
            task.target_path = json_attribs
          end)

          resolution.add_file(SatisfiableFileTask.new(:cookbook_tarball => file_cache_path) do |task|
            task.target_path = cookbook_tarball_path
          end)

          resolution.add_file(SatisfiableFileTask.new(:secret_data_tarball => file_cache_path) do |task|
            task.target_path = secret_data_tarball_path
          end)

          resolution.add_file(SatisfiableFileTask.new(:normal_data_tarball => file_cache_path) do |task|
            task.target_path = normal_data_tarball_path
          end)

          unless role_path.nil?
            directory role_path
            file solo_rb => role_path
          end

          desc "Delete all the chef config files (to re-provision)"
          task :clobber do
            cmd("rm", "-rf", file_cache_path)
          end
        end

        file solo_rb => resolution[:Manifest]
        task :build_configs => solo_rb
      end
    end
  end
end
