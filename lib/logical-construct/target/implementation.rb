require 'mattock/tasklib'

module LogicalConstruct
  module Target
    class Implementation < ::Mattock::Tasklib
      def self.task_list
        [
          :preflight, #Is this node acceptable?
          :settings, #Shared in-memory configuration for the overall setup
          :setup, #write configuration to disk for implementation tools (e.g. Chef, Puppet, apt-get)
          :files, #deliver files from plan to filesystem
          :execute, #run implementation tools
          :configure, #install application configuration files (e.g. /etc/apache/http.conf)
          :complete #All done - depends on everything.
        ]
      end

      default_namespace :construct

      def define
        in_namespace do
          task_spine( *self.class.task_list )

          self.class.task_list.each do |taskname|
            task taskname do
              puts "*** Implementation stage complete: #{taskname}"
            end
          end
        end
      end
    end
  end
end
