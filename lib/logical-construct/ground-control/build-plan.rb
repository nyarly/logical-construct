require 'logical-construct/ground-control'
require 'mattock/tasklib'

module LogicalConstruct::GroundControl
  class BuildPlan < Mattock::Tasklib
    include Mattock::Configurable::DirectoryStructure
    include Mattock::CommandLineDSL

    default_namespace :build_plan

    dir(:plan_source, "source",   path(:plan))
    dir(:marshalling, "marshall", path(:listfile), path(:archive))

    setting :plan_filelist
    setting :exclude_list, ["**/*.sw?"]
    setting :name
    setting :extension, "tbz"
    setting :manifest_task

    def default_configuration(provisioning)
      super
      provisioning.copy_settings_to(self)

      self.manifest_task = provisioning[:manifest]
    end

    def resolve_configuration
      fail_unless_set(:name)
      plan.relative_path ||= name

      self.extension = extension.sub(/^[.]/, "")

      archive.relative_path ||= "#{name}.#{extension}"
      listfile.relative_path ||= "#{name}.list"

      resolve_paths

      self.plan_filelist ||= FileList[plan.absolute_path + "/**"]
      exclude_list.each do |exclusion|
        plan_filelist.exclude(exclusion)
      end

      super
    end

    def define
      super
      in_namespace do
        file listfile.absolute_path => [Rake.application.rakefile, marshalling.absolute_path] + plan_filelist do |task|
          require 'pathname'
          source_pathname = Pathname.new(plan_source.absolute_path)
          plan_files = plan_filelist.map do |path|
            Pathname.new(path).relative_path_from source_pathname
          end

          File::open(listfile.absolute_path, "w") do |list|
            list.write(plan_files.join("\n"))
          end
        end

        file archive.absolute_path => [Rake.application.rakefile, marshalling.absolute_path] + plan_filelist + [listfile.absolute_path] do |task|
          (
            cmd("cd", plan_source.absolute_path) &
            cmd("tar",
                "--exclude-vcs",
                "--create",
                "--auto-compress",
                "--file=" + archive.absolute_path,
                "--files-from=" + listfile.absolute_path)
          ).must_succeed!
        end
      end

      task manifest_task => archive.absolute_path
    end
  end
end
