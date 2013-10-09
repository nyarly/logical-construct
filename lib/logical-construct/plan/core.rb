require 'mattock'
require 'logical-construct/target/implementation'

module LogicalConstruct
  module Plan
    class Core < ::Mattock::Tasklib
      path(:plan_rakefile, "plan.rake")

      def resolve_configuration
        self.absolute_path = plan_rakefile.pathname.dirname

        resolve_paths
        super
      end

      def define
        in_namespace do
          task :compile => 'compile:finished'
          namespace :compile do
            task_spine :preflight, :perform, :finished
          end

          task :install => "install:finished"
          namespace :install do
            task_spine :preflight, :perform, :finished
          end

          Target::Implementation.task_list.each_cons(2) do |first, second|
            task second => "construct:#{first}"
          end
        end

        namespace :construct do
          Target::Implementation.task_list.each do |name|
            task name => self[name]
          end

          [:install, :compile].each do |task|
            task task => self[task]
          end
        end
      end
    end
  end
end
