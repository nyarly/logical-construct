require 'logical-construct/target/platforms/virtualbox'

module LogicalConstruct
  module VirtualBox
    class Volume < Default::Volume
      def define
        Mattock::CommandTask.define_task(self) do |task|
          task.command = Mattock::CommandLine.new("mount") do |mount|
            mount.options = [device, mountpoint]
          end
        end
      end
    end
  end
end
