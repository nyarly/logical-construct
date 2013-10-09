require 'mattock'
require 'logical-construct/archive-tasks'
require 'logical-construct/node-client'
require 'logical-construct/port-open-check'

module LogicalConstruct
  module Target
    class FlightDeck < ::Mattock::Tasklib
      include Mattock::CommandLineDSL
      class ResolutionServerTask < ::Mattock::Rake::Task
        path(:log_file, "resolution-server.log")
        dir(:plans, "plans",
            dir(:delivered, "delivered"),
            dir(:current, "current"),
            dir(:stored, "stored"))

        setting :port, 30712


        def resolve_configuration
          resolve_paths
          super
        end

        def needed?
          if ::Rake.application.options.trace
            ::Rake.application.trace("Checking to see if a service is running at #{port}")
            if TCPPortOpenCheck.new(port).open?
              ::Rake.application.trace("  ...yes - task not needed")
              return false
            else
              ::Rake.application.trace("  ...no - task needed")
              return true
            end
          else
            !TCPPortOpenCheck.new(port).open?
          end
        end

        def action(args)
          require 'roadforest/server'
          require 'logical-construct/target/resolution-server'
          require 'webrick/accesslog'
          services = ResolutionServer::ServicesHost.new

          services.plan_records.directories.delivered = delivered.absolute_path
          services.plan_records.directories.current = current.absolute_path
          services.plan_records.directories.stored = stored.absolute_path

          logfile = File::open(log_file.absolute_path, "a")
          logfile.sync = true

          application = ResolutionServer::Application.new("http://localhost:#{port}", services)
          application.configure do |config|
            config.port = port
            config.adapter_options = {
              :Logger => WEBrick::Log.new(logfile),
              :AccessLog => [
                [logfile, WEBrick::AccessLog::COMMON_LOG_FORMAT ],
                [logfile, WEBrick::AccessLog::REFERER_LOG_FORMAT ]
            ]
            }
          end
          application.run
        end
      end

      class DaemonizedResolutionServerTask < ResolutionServerTask
        def daemonize
          fail "Can't daemonize without a block" unless block_given?

          pid = fork do
            begin
              Process::setsid
              ObjectSpace::each_object(IO) do |io|
                begin
                  if (0..2).cover?(io.fileno)
                    begin
                      io.reopen("/dev/null")
                    rescue IOError => ioe
                      raise "#{ioe.inspect} while trying to reopen #{io}"
                    end
                  else
                    io.close
                  end
                rescue IOError
                  #io errors when closing or fileno aren't a problem
                end
              end

              yield
            rescue Object => ex
              File::open("daemonize-crash-log", "w") do |log|
                log.write("#{([ex.class.name, ex.message, ex.to_s] + ex.backtrace).join("\n")}")
              end
            end

            Kernel.exit!
          end
          Process.detach(pid)
        end

        def action(args)
          daemonize{ super }
        end
      end

      class UniqueProcessTask < ::Mattock::Rake::Task
        dir(:rundir, "run",
            dir(:lockdir, "lock"),
            path(:lockfile))

        def resolve_configuration
          lockfile.relative_path ||= [task_name, "lock"].join(".")
          resolve_paths
          super
        end

        def action(args)
          require 'pathname'
          Pathname.new(lockdir.absolute_path).mkpath
          File::open(lockfile.absolute_path, File::CREAT|File::EXCL|File::WRONLY, 0600) do |file|
            file.write(Process.pid)
          end
          at_exit{ File::unlink(lockfile.absolute_path) }
        rescue Errno::EEXIST
          pid = File::open(lockfile.absolute_path, File::RDONLY) do |file|
            file.read.to_i
          end
          begin
            Process.kill(0, pid)
            puts "Another process (pid: #{pid}) already owns #{lockfile.absolute_path}"
            puts "Exiting"
            exit(1)
          rescue Errno::ESRCH, RangeError
            #process doesn't exist
            File::unlink(lockfile.absolute_path)
          end
          retry #if we get here it's because the previous process is dead and we've cleaned up
        end
      end

      dir(:plans, "plans",
          dir(:delivered, "delivered"),
          dir(:current, "current"),
          dir(:stored, "stored"),
          dir(:plan_dirs, "installs"),
          path(:plans_live, "live"),
          path(:plans_temp, "temp"),
         )

      setting :local_server, "http://localhost:30712/"
      setting :top_level_tasks, []
      setting :plan_options, []
      setting :manifest_path, nil

      default_namespace :flight_deck

      def resolve_configuration
        self.absolute_path = Pathname.pwd.join($0).dirname.dirname.to_s
        resolve_paths
        super
      end

      def define
        in_namespace do
          UniqueProcessTask.define_task(:unique_process)

          namespace :server do
            desc "Run resolution server synchronously"
            ResolutionServerTask.define_task(:run) do |run|
              copy_settings_to(run)
            end

            DaemonizedResolutionServerTask.define_task(:daemonized) do |daemon|
              copy_settings_to(daemon)
            end

            task :report_started => :daemonized do
              puts "** Started resolution server"
            end

            task :deliver_manifest => :report_started do
              unless manifest_path.nil?
                puts "*** the --manifest_path option is a placeholder for the real feature ***"
              end
            end
          end

          namespace :plans do
            task :wait_for_server => "server:deliver_manifest" do
              client = NodeClient.new
              client.node_url = "http://localhost:30712/"

              puts "** Waiting for ground control resolution"
              current_state = nil
              until (state = client.state) == "resolved"
                if current_state != state
                  puts "** Current state: #{state}"
                end
                current_state = state
                sleep 1
              end
              puts "** Server ready - proceeding..."
            end

            desc "Check that current plans are received and unpack them for implementation"
            task :unpack => 'unpack:finished'

            namespace :unpack do
              desc "Remove old versions of the the live plans directory"
              task :clean_up do
                retain = []
                [plans_live.pathname, plans_temp.pathname].each do |path|
                  begin
                    retain << path.realpath
                  rescue Errno::ENOENT
                  end
                end

                if(plan_dirs.pathname.exist?)
                  plan_dirs.pathname.children(true).each do |dir|
                    next if retain.include?(dir)
                    cmd("rm", "-rf", dir.to_s).run
                  end
                end
              end

              directory plan_dirs.absolute_path

              file plans_temp.absolute_path => plan_dirs.absolute_path do
                require 'tmpdir'

                dir = Dir::mktmpdir(nil, plan_dirs.absolute_path)
                cmd("ln") do |link|
                  link.options << "-sfnT"
                  link.options << dir
                  link.options << plans_temp.absolute_path
                end.must_succeed!
              end

              task :make_temp_live do
                cmd("mv") do |mv_t|
                  mv_t.options << "-T"
                  mv_t.options << plans_temp.absolute_path
                  mv_t.options << plans_live.absolute_path
                end.must_succeed!
              end

              #This task creates other tasks here and now for unpacking the
              #current plans - we don't know until now which plan archives
              #we're installing
              #We could sort of use a rule, but we don't know anything about
              #the files in the archives.
              task :all => :wait_for_server do
                complete_task = task :complete

                Pathname.new(current.absolute_path).each_child(true) do |archive_file|
                  name = archive_file.basename.sub(/[.].*\Z/,'').to_s
                  temp_plan = plans_temp.pathname.join(name)

                  namespace(name) do
                    unpack_task = UnpackTarballTask.define_task(:unpack => plans_temp.absolute_path) do |unpack|
                      unpack.unpacked_parent.absolute_path = plans_temp.absolute_path
                      unpack.archive_parent.absolute_path = current.absolute_path
                      unpack.basename = name
                    end
                    unpack_task.create_target_dependencies

                    plan_file = unpack_task.unpacked_dir.pathname.join("plan.rake")
                    file plan_file

                    puts "\n#{__FILE__}:#{__LINE__} => #{unpack_task.target_files.inspect}"
                    task :install => unpack_task.target_files do
                      source_path = unpack_task.unpacked_dir.pathname
                      if (install_rake = source_path.join("plan.rake")).exist?
                        ruby_libs = [source_path.join("lib"), ENV["RUBYLIB"]]
                        (cmd("cd", source_path) &
                         cmd("rake", "--rakefile", install_rake, "#{name}:install").set_env("RUBYLIB", ruby_libs.join(":"))
                        ).must_succeed!
                      end
                    end
                  end

                  task :complete => "#{name}:install"
                end

                complete_task.invoke
              end

              task :tidy_up => [:make_temp_live, :clean_up]
              task :finished => [:wait_for_server, :tidy_up, :make_temp_live]
              task :make_temp_live => :all
            end

            task :implement => :unpack do
              libpath = []
              gempath = []
              rake_modules = []


              plans_live.pathname.each_child(false) do |plan_path|
                if (libdir = plans_live.pathname + plan_path + "lib").directory?
                  libpath << libdir
                end

                if (plan_module = plans_live.pathname + plan_path + "plan.rake").file?
                  rake_modules << plan_path + "plan"
                end
              end

              rake_command = cmd("rake") do |rake|
                rake.options += ["--libdir", plans_live.pathname]
                rake_modules.each do |mod|
                  rake.options += ["--require", mod]
                end

                rake.options << "--rakefile " + File::expand_path("../Implement.rake", __FILE__)

                #rake.options << "--trace"
                rake.options += plan_options

                rake.options += top_level_tasks
                rake.command_environment["RUBYLIB"] = libpath.join(":")
              end

              puts "*** Beginning Implementation"
              rake_command.replace_us
            end

            task :wait_for_server => :unique_process
            file plans_temp.absolute_path => :unique_process
            task :implement => :unique_process
          end

          task :implement => 'plans:implement'
          task :start_server => 'server:daemonized'
        end
      end
    end
  end
end
