require 'logical-construct/ground-control'
require 'mattock/tasklib'
require 'logical-construct/archive-tasks'

module LogicalConstruct::GroundControl
  class BuildPlan < Mattock::Tasklib
    include Mattock::CommandLineDSL

    default_namespace :build_plan

    setting :manifest_task

    dir(:plan_source, "source",
        dir(:plan, path(:plan_rakefile, "plan.rake")))
    dir(:marshalling, "marshall",
        dir(:plan_temp,
            dir(:synced, "sync")))

    setting :source_pattern, "**/*"
    setting :exclude_patterns, ["**/*.sw[p-z]"] #ok
    setting :basename

    setting :synced_files

    def default_configuration(provisioning)
      super
      provisioning.copy_settings_to(self)

      self.manifest_task = provisioning[:manifest]
    end

    def resolve_configuration
      fail_unless_set(:basename)
      plan.relative_path ||= basename
      plan_temp.relative_path ||= basename

      resolve_paths

      self.synced_files =
        begin
          pattern = File::join(plan.absolute_path, source_pattern)
          list = FileList[pattern]
          exclude_patterns.each do |pattern|
            list.exclude(pattern)
          end
          list.map do |path|
            synced.pathname.join(Pathname.new(path).relative_path_from(plan.pathname)).to_s
          end
        end

      super
    end

    def archive_path
      @pack.archive.absolute_path
    end

    def define
      super

      in_namespace do
        task :compile do
          (cmd("cd", plan.absolute_path) & cmd("rake", "--rakefile", plan_rakefile.absolute_path, "construct:compile")).must_succeed!
        end

        file_create synced.absolute_path do |dir|
          cmd("mkdir", "-p", dir.name).must_succeed! #ok
        end

        #This looks absurd, but otherwise we need to make sure that no compile
        #task creates a new file it doesn't need. `bundle standalone` already
        #does, so...
        task :rsync_artifacts => [synced.absolute_path, :compile] do
          from_dir = plan.absolute_path
          from_dir += "/" unless from_dir =~ %r"/$"

          to_dir = synced.absolute_path
          to_dir += "/" unless to_dir =~ %r"/$"

          cmd("rsync", "-v", "-rlpgo", "--checksum", from_dir, to_dir).must_succeed!
        end

        synced_files.each do |path|
          file path => :rsync_artifacts
        end

        @pack = ::LogicalConstruct::PackTarball.new do |pack|
          copy_settings_to(pack)
          pack.source_files = synced_files
          pack.unpacked_dir.absolute_path = synced.absolute_path
        end
      end
    end
  end
end
