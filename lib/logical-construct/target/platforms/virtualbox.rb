require 'logical-construct/target/platforms'

module LogicalConstruct
  module VirtualBox
    extend PlatformSpecific
    register_platform('virtualbox')
  end
end
