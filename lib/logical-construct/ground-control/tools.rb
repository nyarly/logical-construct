require 'mattock'

module LogicalConstruct
  module GroundControl
    class Tools < ::Mattock::Tasklib
      include Mattock::CommandLineDSL

      default_namespace :tools

      dir(:plans, "plans")

      def resolve_configuration
        resolve_paths
        super
      end

      def plans_dir
        plans.absolute_path.sub(%r{/$},'')
      end

      def define
        in_namespace do
          namespace :create_plan do
            rule %r{\A#{plans_dir}/[^/]*\Z} do |task, args|
              cmd("mkdir", "-p", task.name).must_succeed! #ok
            end

            rule(%r{\A#{plans_dir}/[^/]*/plan\.rake\Z}, [:name] => ['%d']) do |task, args|
              require 'logical-construct/target/implementation'

              File::open(task.name, "w") do |file|
                indent = 16
                file.write(<<-EOR.gsub(/^#{" "*indent}/,''))
                require 'logical-construct/plan'
                include LogicalConstruct::Plan

                core = Core.new do |core|
                  core.namespace_name = :#{args[:name]}
                  core.plan_rakefile.absolute_path = __FILE__
                end

                core.in_namespace do
                  #Plan tasks go here
                  #
                  #Important tasks to make dependencies to:

                EOR

                Target::Implementation.task_list.each do |task_name|
                  file.puts("  #task :#{task_name}")
                end

                file.puts("end")
              end
            end
          end

          desc "Create a new plan to be part of a provisioning"
          task :create_plan, [:name] do |task, args|
            Rake::Task[File::join(plans_dir, args[:name], "plan.rake")].invoke(args[:name])
          end
        end
      end
    end
  end
end
