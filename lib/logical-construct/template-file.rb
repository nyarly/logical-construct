require 'mattock'
module LogicalConstruct
  class TemplateFile < Mattock::TaskLib
    include Mattock::TemplateHost
    include Mattock::DeferredDefinition
    Mattock::DeferredDefinition.add_settings(self)

    setting(:valise, nil)
    setting(:templates)

    dir(:target_dir, path(:target))

    setting(:base_name)
    setting(:extra, {})

    def default_configuration(host)
      super
      host.copy_settings_to(self)
    end

    def resolve_configuration
      target.relative_path ||= base_name
      resolve_paths

      if field_unset?(:templates)
        self.templates = fail_unless_set(:valise) && valise.templates
      end

      super
    end

    def define
      file target.absolute_path => [target_dir, templates.find(base_name).full_path, Rake.application.rakefile] do
        finalize_configuration
        File::open(target.absolute_path, "w") do |file|
          file.write templates.find(base_name).contents.render(nil, extra)
        end
      end
    end
  end
end
