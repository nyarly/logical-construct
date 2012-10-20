require 'mattock'

module LogicalConstruct
  module GroundControl
    class Provision < Mattock::Tasklib
      class WebConfigure < Mattock::Task
        setting :target_protocol, "http"
        setting :target_address, nil
        setting :target_port, 51076
        runtime_setting :target_url
        setting :resolutions, {}

        def resolve_runtime_configuration
          super
          self.target_url ||= "#{target_protocol}://#{target_address}:#{target_port}/"
        end

        def resolve(path)
          resolved = resolutions.fetch(path)
          if resolved.respond_to? :call
            resolved = resolved.call
          end
          return resolved
        end

        #XXX I would like this to become an actual RESTful client at some
        #point, but seems it would mean building it from scratch
        def action
          require 'uri'
          require 'rest-client'
          require 'nokogiri'
          uri_class = URI.scheme_list[target_protocol.upcase]
          uri_hash = {:host => target_address, :port => target_port}

          index_uri = uri_class.build(uri_hash.merge(:path => '/'))
          index = RestClient.get(index_uri.to_s)

          body = Nokogiri::HTML(index.body)
          resolution_needed = body.xpath('//a[@href]')
          resolution_needed.each do |link|
            href = link['href']
            post_uri = uri_class.build(uri_hash.merge(:path => href))
            response = RestClient.post(post_uri.to_s, :data => resolve(href))
            unless (200..299).include? response.code
              require 'tempfile'
              file = Tempfile.open('provision-error.html')
              path = file.path
              file.close!

              File::open(path, "w") do |file|
                file.write response.body
              end
              puts "Written error response to #{path}"
              puts "Try: chromium #{path}"
              fail "Unsuccessful response from server!"
            end
          end
        end
      end

      default_namespace :provision

      setting :valise
      setting :target_protocol, "http"
      setting(:target_address, nil).isnt(:copiable)
      setting :target_port, 51076
      setting :resolutions, {}
      setting :marshalling_path
      setting :cookbooks_path
      setting :cookbooks_tarball_path
      setting :json_attribs_path

      def default_configuration(core)
        core.copy_settings_to(self)
        super
      end

      def resolve_configuration
        super
        #XXX Find in Valise?
        self.json_attribs_path ||= File::join(marshalling_path, "node.json")
        self.cookbooks_tarball_path ||= File::join(marshalling_path, "cookbooks.tgz")

        resolutions["/chef_config/json_attribs"] ||= proc do
          File::open(json_attribs_path, "rb")
        end

        resolutions["/chef_config/cookbook_tarball"] ||= proc do
          File::open(cookbooks_tarball_path, "rb")
        end
      end

      include Mattock::CommandLineDSL
      def define
        in_namespace do
          directory marshalling_path

          task :collect, [:ipaddr] do |task, args|
            self.target_address = args[:ipaddr]
          end

          WebConfigure.new(:web_configure => [:collect, json_attribs_path, cookbooks_tarball_path]) do |task|
            self.copy_settings_to(task)
            task.target_address = proxy_value.target_address
          end

          file cookbooks_tarball_path => [marshalling_path] + Rake::FileList[cookbooks_path + "/**/*"] do
            cmd("tar", "czf", cookbooks_tarball_path, cookbooks_path).must_succeed!
          end
        end

        task root_task, [:ipaddr] => self[:web_configure]
      end
    end
  end
end
