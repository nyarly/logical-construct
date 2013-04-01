require 'mattock/tasklib'
require 'mattock/template-host'
require 'mattock/command-line'
require 'logical-construct/satisfiable-task'

module LogicalConstruct
  module Default
    #XXX Should get broken into at least 2 smaller tasklibs
    class ChefConfig < Mattock::Tasklib
      include Mattock::TemplateHost
      include DirectoryStructure

      default_namespace :chef_config

      required_field :construct_dir
      required_fields :cookbook_path, :data_bags_path, :json_attribs,
        :cookbook_tarball_path, :file_cache_path, :secret_data_tarball_path, :normal_data_tarball_path
      required_field :valise

      dir(:etc_chef, path(:solo_rb, "solo.rb"))

      dir(:construct_dir,
          dir(:file_cache_path, "chef",
              path(:data_bags, "data-bags"),
              path(:cookbook, "cookbooks"),
              path(:cookbook_tarball, "cookbooks.tgz"),
              path(:secret_data_tarball, "secret_data.tgz"),
              path(:normal_data_tarball, "normal_data.tgz"),
              path(:json_attribs, "node.json")
             ))

      setting :resolution

      nil_fields :recipe_url, :role_path, :role_relpath

      def default_configuration(provision, resolution)
        super
        self.construct_dir.absolute_path = provision.construct_dir
        self.valise = provision.valise
        self.resolution = resolution
      end

      #XXX Hints about decomposing this Tasklib: there are settings for
      #chef/solo.rb, which are only incidentally related to the tarball
      #unpacking tasks - which are themselves closely related
      def resolve_configuration
        construct_dir.absolute_path = File::expand_path(construct_dir.absolute_path)

        resolve_paths

        if role_path.nil? and !role_relpath.nil?
          self.role_path = File::expand_path(role_relpath, file_cache_path)
        end
        super
      end

      include Mattock::CommandLineDSL
      def define
        in_namespace do
          directory etc_chef.absolute_path
          directory file_cache_path.absolute_path

          #TODO Convert to Unpack Tasklibs
          Mattock::CommandTask.define_task(:unpack_cookbooks => :cookbook_tarball) do |task|
            task.command = cmd("cd", file_cache.absolute_path) & cmd("tar", "-xzf", cookbook_tarball.absolute_path)
          end

          Mattock::CommandTask.define_task(:unpack_secret_data => :secret_data_tarball) do |task|
            task.command = cmd("cd", file_cache.absolute_path) & cmd("tar", "-xzf", secret_data_tarball.absolute_path)
          end

          Mattock::CommandTask.define_task(:unpack_normal_data => :normal_data_tarball) do |task|
            task.command = cmd("cd", file_cache.absolute_path) & cmd("tar", "-xzf", normal_data_tarball.absolute_path)
          end

          file solo_rb.absolute_path => [etc_chef, :json_attribs, :unpack_cookbooks, :unpack_secret_data, :unpack_normal_data] do
            File::open(solo_rb.absolute_path, "w") do |file|
              file.write(render("chef.rb.erb"))
            end
          end

          [ [:json_attribs, json_attribs],
            [:cookbook_tarball, cookbook_tarball],
            [:secret_data_tarball, secret_data_tarball],
            [:normal_data_tarball, normall_data_tarball] ].each do |task_name, target_file|
            resolution.add_file(SatisfiableFileTask.define_task(task_name => file_cache.absolute_path) do |task|
              task.target_path = target_file.absolute_path
            end)
            end


          unless role_path.nil?
            directory role.absolute_path
            file solo_rb.absolute_path => role.absolute_path
          end

          desc "Delete all the chef config files (to re-provision)"
          task :clobber do
            cmd("rm", "-rf", file_cache.absolute_path)
          end
        end

        file solo_rb.absolute_path => resolution[:Manifest]
        task :build_configs => solo_rb.absolute_path
      end
    end
  end
end
