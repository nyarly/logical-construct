require 'logical-construct/target/platforms'

module LogicalConstruct
  module AWS
    extend PlatformSpecific
    register_platform
  end

  require_platform_files('aws')
end
