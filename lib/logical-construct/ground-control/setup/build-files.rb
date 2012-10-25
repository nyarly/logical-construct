require 'mattock'
require 'mattock/bundle-command-task'

module LogicalConstruct
  class ConfigBuilder < Mattock::TaskLib
    include Mattock::TemplateHost
    include Mattock::DeferredDefinition
    Mattock::DeferredDefinition.add_settings(self)

    setting(:source_path, nil)
    setting(:target_path, nil)

    setting(:valise)
    setting(:target_dir)

    setting(:base_name)
    setting(:extra, {})

    def default_configuration(host)
      super
      host.copy_settings_to(self)
    end

    def resolve_configuration
      self.target_path ||= fail_unless_set(:target_dir) && File::join(target_dir, base_name)
      self.source_path ||= fail_unless_set(:base_name)  && "#{base_name}.erb"
      super
    end

    def define
      file target_path => [target_dir, valise.find("templates/" + source_path).full_path, Rake.application.rakefile] do
        finalize_configuration
        p extra
        File::open(target_path, "w") do |file|
          file.write render(source_path)
        end
      end
      file target_path => target_dir
      task :local_setup => target_path
    end
  end

  class BuildFiles < Mattock::TaskLib
    include Mattock::CommandLineDSL

    default_namespace :build_files

    setting(:target_dir, "target_configs")
    required_fields :valise, :construct_dir, :platform

    def default_configuration(parent)
      super
      self.valise = parent.valise
      self.construct_dir = parent.construct_dir
      self.platform = parent.proxy_value.platform
    end

    def define
      rakefile = nil
      initd = nil
      in_namespace do
        directory target_dir

        gemfile = ConfigBuilder.new(self) do |task|
          task.base_name = "Gemfile"
        end

        Mattock::BundleCommandTask.new(:standalone => gemfile.target_path) do |bundle_build|
          bundle_build.command = (
            cmd("cd", target_dir) &
            cmd("bundle", "install"){|bundler|
            bundler.options << "--standalone"
            bundler.options << "--binstubs=bin"
          })
        end

        rakefile = ConfigBuilder.new(self) do |task|
          task.base_name = "Rakefile"
        end

        initd = ConfigBuilder.new(self) do |task|
          task.base_name = "construct.init.d"
          task.extra[:construct_dir] = construct_dir
          task.runtime_definition do
            task.extra[:platform] = platform
          end
        end
      end
      desc "Template files to be created on the remote server"
      task root_task => [rakefile.target_path] + in_namespace(:standalone)
      task root_task => [initd.target_path] + in_namespace(:standalone)
      task :local_setup => root_task
    end
  end
end
