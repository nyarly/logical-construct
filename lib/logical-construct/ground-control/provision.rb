require 'mattock'
require 'json'
require 'logical-construct/resolving-task'

module LogicalConstruct
  module GroundControl
    class Provision < Mattock::Tasklib
      class WebConfigure < Mattock::Task
        include ResolutionProtocol

        setting :target_protocol, "http"
        setting :target_address, nil
        setting :target_port, 51076
        runtime_setting :target_url
        setting :resolutions
        runtime_setting :web_resolutions

        def resolve_runtime_configuration
          super
          self.target_url ||= "#{target_protocol}://#{target_address}:#{target_port}/"
          self.web_resolutions = Hash[resolutions.map do |name, value|
            [web_path(name), value]
          end]
        end

        def resolve(path)
          resolved = web_resolutions.fetch(path)
          if resolved.respond_to? :call
            resolved = resolved.call
          end
          return resolved
        rescue KeyError
          puts "Can't find a resolution for #{path} in #{web_resolutions.keys.inspect} (ex #{resolutions.keys})"
          raise
        end

        def uri(options)
          uri_class = URI.scheme_list[target_protocol.upcase]
          uri_hash = {:host => target_address, :port => target_port}
          return uri_class.build(uri_hash.merge(options)).to_s
        end

        def resolution_needed
          index = RestClient.get(uri(:path => '/'))
          body = Nokogiri::HTML(index.body)
          return body.xpath("//a[@rel='requirement']")
        end


        #XXX I would like this to become an actual RESTful client at some
        #point, but seems it would mean building it from scratch
        def action
          require 'uri'
          require 'rest-client'
          require 'nokogiri'

          until (link = resolution_needed.first).nil?
            href = link['href']
            begin
              response = RestClient.post(uri(:path => href), :data => resolve(href))
            rescue RestClient::InternalServerError => ex
              require 'tempfile'
              file = Tempfile.open('provision-error.html')
              path = file.path
              file.close!

              File::open(path, "w") do |file|
                file.write ex.http_body
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
      setting :resolutions
      setting :marshalling_path, "marshall"

      setting(:secret_data, nested {
        setting :path
        setting :tarball_path
        setting :file_list
      })

      setting(:normal_data, nested {
        setting :path
        setting :tarball_path
        setting :file_list
      })

      setting(:cookbooks, nested {
        setting :path
        setting :tarball_path
        setting :file_list
      })

      setting :json_attribs_path
      setting :roles
      setting :node_attribs
      setting :json_attribs, ""

      def default_configuration(core)
        core.copy_settings_to(self)
        super
        self.cookbooks.path = "cookbooks"
        self.secret_data.path = "data-bags/secret"
        self.normal_data.path = "data-bags"
        self.resolutions = {}
        self.roles = {}
        self.node_attribs = { "run_list" => [] }
      end

      def resolve_configuration
        super
        self.json_attribs_path ||= File::join(marshalling_path, "node.json")

        self.cookbooks.file_list ||= Rake::FileList[cookbooks.path + "/**/*"].exclude(%r{/[.]git/}).exclude(%r{[.]sw[.]$})
        self.secret_data.file_list ||= Rake::FileList[secret_data.path + "/**/*"].exclude(%r{[.]sw[.]$})
        self.normal_data.file_list ||=
          Rake::FileList[normal_data.path + "/**/*"].exclude(%r{^#{secret_data.path}}).exclude(%r{[.]sw[.]$})

        self.cookbooks.tarball_path ||= File::join(marshalling_path, "cookbooks.tgz")
        self.secret_data.tarball_path ||= File::join(marshalling_path, "secret_data_bags.tgz")
        self.normal_data.tarball_path ||= File::join(marshalling_path, "normal_data_bags.tgz")

        resolutions["chef_config:cookbook_tarball"] ||= proc do
          File::open(cookbooks.tarball_path, "rb")
        end

        resolutions["chef_config:secret_data_tarball"] ||= proc do
          File::open(secret_data.tarball_path, "rb")
        end

        resolutions["chef_config:normal_data_tarball"] ||= proc do
          File::open(normal_data.tarball_path, "rb")
        end
      end

      include Mattock::CommandLineDSL
      def define
        in_namespace do
          directory marshalling_path

          task :collect, [:ipaddr] do |task, args|
            self.target_address = args[:ipaddr]
          end

          task :build_json_attribs, [:role] do |task, args|
            unless args[:role].nil?
              self.node_attribs["run_list"] = roles[args[:role]]
            end
            self.json_attribs = JSON.pretty_generate(node_attribs)
            resolutions["chef_config:json_attribs"] ||= json_attribs
          end

          desc "Print attribs (optionally: for :role)"
          task :inspect_attribs, [:role] => :build_json_attribs do
            puts json_attribs
          end

          file secret_data.tarball_path => [marshalling_path] + secret_data.file_list do
            cmd("tar", "--exclude **/*.sw?", "-czf", secret_data.tarball_path, secret_data.path).must_succeed!
          end

          file normal_data.tarball_path => [marshalling_path] + normal_data.file_list do
            cmd("tar",
                "--exclude **/*.sw?",
                "--exclude #{secret_data.path}",
                "-czf", normal_data.tarball_path, normal_data.path).must_succeed!
          end

          file cookbooks.tarball_path => [marshalling_path] + cookbooks.file_list do
            cmd("tar", "--exclude .git", "--exclude **/*.sw?", "-czf", cookbooks.tarball_path, cookbooks.path).must_succeed!
          end

          manifest = LogicalConstruct::GenerateManifest.new(self, :manifest =>
                                                            [
                                                              cookbooks.tarball_path,
                                                              secret_data.tarball_path,
                                                              normal_data.tarball_path,
                                                              :collect
                                                            ]) do |manifest|
            manifest.receiving_name = "configuration:Manifest"
          end

          WebConfigure.new(:web_configure => [:collect, :build_json_attribs, :manifest, cookbooks.tarball_path]) do |task|
            self.proxy_settings_to(task)
            task.target_address = proxy_value.target_address
          end
        end

        desc "Provision :ipaddr with specified configs (optionally: for :role)"
        task root_task, [:ipaddr, :role] => self[:web_configure]
      end
    end
  end
end
