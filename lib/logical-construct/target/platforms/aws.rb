require 'logical-construct/target/platforms'

module LogicalConstruct
  module AWS
    extend PlatformSpecific
    register_platform('aws')
  end
end
