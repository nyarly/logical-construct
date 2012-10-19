require 'mattock'
require 'rake/packagetask'

module LogicalConstruct
  module GroundControl
    class Provision < Mattock::Tasklib
      class WebConfigure < Mattock::Task
        setting :target_protocol, "http"
        setting :target_address, nil
        setting :target_port, 51076
        setting :target_url
        setting :resolutions, {}

        def resolve_configuration
          super
          self.target_url ||= "#{target_protocol}://#{target_address}:#{target_port}/"
        end

        def action
          require 'uri'
          require 'excon'
          require 'nokogiri'
          connection = Excon.new(target_url)
          index = connection.get
          body = Nokogiri::HTML(index.body)
          resolution_needed = body.xpath('//a[@href]')
          resolution_needed.each do |link|
            href = link['href']
            connection.post(:path => href, :body => "data=#{resolve(href)}")
          end
        end

        def resolve(path)
          resolved = resolutions.fetch(path)
          if resolved.respond_to? :call
            resolved = resolved.call
          end
          return resolved
        end
      end

      default_namespace :provision

      setting :valise
      setting :target_protocol, "http"
      setting :target_address, nil
      setting :target_port, 51076
      setting :resolutions, {}
      setting :marshalling_path
      setting :cookbooks_path

      def default_configuration(core)
        core.copy_settings_to(self)
        super
      end

      def define
        in_namespace do
          task :collect, [:ipaddr] do |task, args|
            self.target_url = args[:ipaddr]
          end

          WebConfigure.new(:web_configure => :collect) do |task|
            self.copy_settings_to(task)
          end

          namespace :cookbook do
            Rake::PackageTask.new("cookbook", :noversion) do |task|
              task.need_tar_gz = true
              task.package_dir = marshalling_path
              task.package_files.include(cookbooks_path + "/**/*")
            end
          end
        end

        task root_task, [:ipaddr] => :web_configure
      end
    end
  end
end
