require 'logical-construct/resolving-task'
require 'mattock/task'
require 'mattock/template-host'
require 'sinatra'

module LogicalConstruct
  class SinatraResolver < ResolvingTask
    include Mattock::TemplateHost

    include ResolutionProtocol

    def build_collector(resolver, prereqs)
      klass = Class.new(Sinatra::Application) do
        class << self
          attr_accessor :running_server
        end

        set :show_exceptions => true

        get '/' do
          resolver.render('resolver/index.html.erb')
        end

        prereqs.each do |task|
          path = resolver.web_path(task.name)

          get path do
            if task.prefer_file?
              resolver.render('resolver/task-file-form.html.erb') do |locals|
                locals[:task_path] = path
              end
            else
              resolver.render('resolver/task-form.html.erb') do |locals|
                locals[:task_path] = path
              end
            end
          end

          post path do
            if request.content_type =~ %r{multipart/form-data}
              task.receive(request.params["data"][:tempfile])
            else
              task.receive(request.params["data"])
            end
            if resolver.needed?
              redirect to("/")
            else
              resolver.render('resolver/finished.html.erb')
              quit!
            end
          end
        end

        def self.rack_handler
          handler = detect_rack_handler
        end

        def quit!
          self.class.quit!(self.class.running_server, "A server")
        end
      end
      return klass
    end

    setting :bind, "127.0.0.1"
    setting :port, 51076 #JDL's birthday
    setting :valise

    def action
      puts
      puts "STARTING WEB LISTENER TO RESOLVE PREREQUISITES"
      puts

      collector = build_collector(self, satisfiables)
      handler      = collector.rack_handler
      handler_name = handler.name

      old_handlers = nil
      handler.run collector, :Host => bind, :Port => port do |server|
        old_handlers = Hash[
          [:INT, :TERM].map { |sig| [sig, trap(sig) { collector.quit!(server, handler_name) }] }
        ]
        collector.running_server = server
        if server.respond_to? :threaded=
          server.threaded = settings.threaded
        end
        puts "Listening on #{port} with #{handler.name}"
      end

      old_handlers.each_pair do |signal, handler|
        trap(signal, handler)
      end

    rescue Errno::EADDRINUSE => e
      puts "Port #{port} in use!"
      raise
    end
  end
end
