require 'mattock/task-lib'
require 'mattock/command-line'

module LogicalConstruct
  module AWS
    class Bake
      include CommandLineDSL

      default_namespace :bake

      def define
        in_namespace do
          task :begin do
            #??? Do I need the bundle exec?
            cmd("bundle exec rake #{self[:run]}").spin_off
          end

          desc "Trigger long running local system bake task"
          task :run
        end
        task :bake => self[:begin]
      end
    end
  end
end
