require 'mattock'
require 'logical-construct/node-client'

module LogicalConstruct
  module Target
    class FlightControl < ::Mattock::Tasklib
      include Mattock::CommandLineDSL
      dir(:construct_root,
          dir(:current_archives),
          dir(:plans, "plans",
             path(:plans_live, "live"),
             path(:plans_temp, "temp"),
             dir(:plan_dirs, "installs")
             )
         )

      setting :local_server, "http://localhost:51076/"

      def define
        in_namespace do
          namespace :server do
            task :run do

            end

            task :run_daemon do

            end
          end

          namespace :plans do
            desc "Check that current plans are received and unpack them for implementation"
            task :unpack => 'unpack:finished'

              #server up
              #server complete
              #unpack each from current to plans_temp
              #each in plans_temp:
              #  run install rake - leave skipping unneeded to install
              #rm -rf plans_live
              #mv plans_temp live plans
              #  OR
              #plans_live + plans_temp are symlinks:
              #mv -T plans_temp plans_live
              #rm -rf old target of plans_live

            namespace :unpack do
              desc "Remove old versions of the the live plans directory"
              task :clean_up do
                retain = []
                [plans_live.absolute_path, plans_temp.absolute_path].each do |path|
                  begin
                    retain << path.realpath
                  rescue Errno::ENOENT
                  end
                end

                plan_dirs.absolute_path.children(true).each do |dir|
                  next if retain.include?(dir)
                  cmd("rm", "-rf", dir.to_s)
                end
              end

              task :server_up do
                TCPPortOpenCheck.new(51076).fail_if_open!
              end

              task :server_complete => :server_up do
                client = NodeClient.new("http://localhost:51076/")
                unless client.resolved?
                  fail "Server does not have resolved plans: #{client.state}"
                end
              end

              file plans_temp.absolute_path do
                require 'tmpdir'

                dir = Dir::mktmpdir(nil, plan_dirs.absolute_path)
                cmd("ln") do |link|
                  link.options << "-sfn"
                  link.options << dir
                  link.options << plans_temp.absolute_path
                end
              end

              task :make_temp_live do
                cmd("mv") do |mv_t|
                  mv_t.options << "-T"
                  mv_t.options << plans_temp.absolute_path
                  mv_t.options << plans_live.absolute_path
                end.must_succeed!
              end

              task :tidy_up => :clean_up
              task :finished => :server_complete, :tidy_up

              current_archives.absolute_plan.each_child(true) do |archive_file|
                name = archive_file.basename.sub(/[.]*\Z/,'')
                temp_plan = plans_temp.absolute_path.join(name)
                live_plan = plans_live.absolute_path.join(name)

                file archive_file
                file temp_plan => [:server_complete, archive_file] do
                  (cmd("cd", plans_temp.absolute_path) &
                   cmd("tar"){|tar|
                    tar.options << "--versose"
                    tar.options << "--extract"
                    tar.options << "--auto-compress"
                    tar.options << "--file="+archive_file
                  }).must_succeed!

                  if (install_rake = temp_plan.join("install.rake")).exists?
                    ruby_libs = [temp_plan.join("lib"), ENV["RUBYLIB"]]
                    (cmd("cd", temp_plan) &
                     cmd("rake", "-F", install_rake).command_environment["RUBYLIB"] = ruby_libs.join(":")
                    ).must_succeed!
                  end
                end

                file live_plan => [temp_plan, :make_temp_live]
                task :make_temp_live => temp_plan
                task :tidy_up => live_plan
                task :finished => live_plan
              end
            end

            task :implement do
              libpath = []
              gempath = []
              rake_modules = []
              Pathname.new(plans_live).each_entry do |plan_path|
                if (libdir = plan_path + "lib").directory?
                  libpath << libdir
                end

                if (gemdir = plan_path + "gems").directory?
                  gempath << gemdir
                end

                if (plan_module = plan_path + "plan.rake").file?
                  rake_modules << plan_module
                end
              end

              rake_command = cmd("rake") do |rake|
                rake_modules.each do |mod|
                  rake.options += ["-r", mod]
                end

                rake.options << "-F Implement.rake"
              end

              rake_command.command_environment["RUBYLIB"] = lib_path.join(":")
              rake_command.command_environment["GEM_PATH"] = gempath.join(":")

              rake_command.replace_us
              #Never get here
            end
          end
        end
      end
    end
  end
end
