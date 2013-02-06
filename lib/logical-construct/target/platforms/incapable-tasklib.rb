require 'mattock/task-lib'

module LogicalConstruct
  class IncapableTasklib < Mattock::Tasklib
    def fail_incapable
      $stderr.puts "Target incapable of that action"
      $stderr.puts "Platform is: #{LogicalConstruct::Platform().name}"
      exit 13 #Arbitrary to mean "target incapable"
    end

    def define
      in_namespace do
        task :incapable do
          fail_incapable
        end
      end
    end

    def cant_do(*tasks)
      in_namespace do
        tasks.each do |name|
          task name => :incapable
        end
      end
    end
  end
end
