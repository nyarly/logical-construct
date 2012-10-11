module LogicalConstruct
  class ConfigBuilder < Mattock::TaskLib
    include Mattock::TemplateHost

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
      self.target_path ||= File::join(target_dir, base_name)
      self.source_path ||= "#{base_name}.erb"
      super
    end

    def define
      file target_path => [target_dir, valise.find("templates/" + source_path).full_path, Rake.application.rakefile] do
        File::open(target_path, "w") do |file|
          file.write render(source_path)
        end
      end
      task :local_setup => target_path
    end
  end

  class BuildFiles < Mattock::TaskLib
    default_namespace :build_files

    setting(:target_dir, "target_configs")
    setting(:valise)

    def default_configuration(parent)
      super
      self.valise = parent.valise
    end

    attr_reader :built_files

    def define
      file_tasks = []
      in_namespace do
        directory target_dir

        file_tasks = ["Rakefile", "Gemfile"].map do |path|
          ConfigBuilder.new(self) do |task|
            task.base_name = path
          end
        end
      end
      desc "Template files to be created on the remote server"
      task root_task => file_tasks.map{|t| t.target_path}
      task :local_setup => root_task
    end
  end
end
