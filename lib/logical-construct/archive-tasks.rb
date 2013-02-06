require 'mattock/command-task'
require 'mattock/tasklib'
module LogicalConstruct
  module TarballOptions
    def self.included(mod)
      mod.setting :compression, :gzip
    end

    def compression_flag
      case compression
      when :gzip
        "z"
      when :bzip, :bzip2
        "j"
      when :xz
        "J"
      else
        ""
      end
    end

    def tar_command(action)
      command = cmd("tar", "#{action}#{compression_flag}f")
      exclude_patterns.each do |pattern|
        command.options += ["--exclude", pattern]
      end
      command.options << target_path
      command.options += source_files
      return command
    end
  end

  class PackTarballTask < Mattock::Rake::FileCommandTask
    include TarballOptions

    setting :source_dir
    setting :source_files
    setting :source_pattern, "**"

    setting :exclude_patterns, []

    def resolve_configuration
      super
      self.source_files ||= FileList[File::join(source_dir, source_pattern)]
      self.command = tar_command("c")
    end

    def needed?
      return true if super
      if File::exists?(target_path)
        list_process = cmd("tar", "d#{compression_flag}f", target_path, source_dir).run
        return !list_process.succeeded?
      end
      return true
    end

    def define
      super
      if prerequisite_tasks.empty?
        enhance(source_files)
      end
    end
  end

  class UnpackTarballTask < Mattock::Rake::FileCommandTask
    include TarballOptions

    setting :target_dir
    setting :archive_path

    def resolve_configuration
      super
      self.command = (cmd("mkdir", "-p", target_dir) & cmd("tar", "x#{compression_flag}f", archive_path, "-C", target_dir))
    end

    def needed?
      File.exists?(name)
    end
  end

  class RemoveFilesNotInArchives < Mattock::Rake::CommandTask
    include TarballOptions

    setting :archive_paths
    setting :archive_files, []
    setting :target_dir
    setting :file_list

    attr_accessor :stray_files

    def resolve_configuration
      super

      archive_paths.each do |archive_path|
        list_process = cmd("tar", "t#{compression_flag}f", archive_path).run
        if list_process.succeeded?
          self.archive_files += list_process.stdout.lines.to_a.map{|line| line.chomp}
        end
      end
      archive_files.map!{|path| File::expand_path(path, target_dir)}

      self.stray_files = file_list - archive_files
      stray_files.delete_if{|path| File::directory?(path)}
      unsafe_cleanup = stray_files.find_all do |path|
        %r{\A/} =~ path and not %r{\A#{File::expand_path(target_dir)}} =~ path
      end
      raise "Unsafe stray cleanup: #{unsafe_cleanup.inspect}" unless unsafe_cleanup.empty?


      self.command = cmd("rm", "-f", *stray_files)
    end

    def needed?
      stray_files.any? do |path|
        File.exists?(path)
      end
    end
  end

  class UnpackTarball < Mattock::Tasklib
    default_namespace :unpack

    setting :archive_paths

    setting :target_dir
    setting :target_pattern, "**/*"
    setting :file_list

    def resolve_configuration
      super
      self.file_list = FileList["#{File::expand_path(target_dir)}/#{target_pattern}"]
    end

    def define
      in_namespace do
        archive_paths.each do |archive|
          UnpackTarballTask.define_task(archive) do |unpack|
            copy_settings_to(unpack)
            unpack.archive_path = archive
          end
        end

        RemoveFilesNotInArchives.define_task(:remove_strays => archive_paths) do |remove_strays|
          copy_settings_to(remove_strays)
        end

        if file_list.empty?
          task :unpack => :remove_strays
        else
          task :unpack => file_list
          file_list.each do |path|
            file path => :remove_strays
          end
        end
      end

      task namespace_name => self[:unpack]
    end
  end
end
