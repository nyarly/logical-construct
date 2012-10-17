module LogicalConstruct
  def self.platforms
    @platforms ||= {}
  end

  def self.register_platform(mod)
    name = mod.name.split('::').last
    platforms[name] = mod
  end

  def self.require_platform_files(platform, mod = nil)
    [
      ['volume', :Volume],
      ['chef-config', :ChefConfig],
      ['resolve-configuration', :ResolveConfiguration],
    ].each do |file, classname|
      begin
        require File::join('logical-construct', 'target', 'platforms', platform, file)
      rescue LoadError
        raise if mod.nil?
        klass = Class.new(LogicalConstruct::Default.const_get(classname))
        mod.const_set(classname, klass)
      end
    end
  end

  def self.Platform(explicit = nil)
    name = explicit || $DEPLOYMENT_PLATFORM || ENV['LOGCON_DEPLOYMENT_PLATFORM']
    return platforms.fetch(name)
  rescue KeyError
    puts "Cannot find platform specified:"
    puts "  explicit argument: #{explicit.inspect}"
    puts "  $DEPLOYMENT_PLATFORM: #{$DEPLOYMENT_PLATFORM.inspect}"
    puts "  ENV['LOGCON_DEPLOYMENT_PLATFORM']: #{ENV['LOGCON_DEPLOYMENT_PLATFORM'].inspect}"
    puts "  available: #{platforms.keys.inspect}"
    puts
    raise
  end

  module PlatformSpecific
    def register_platform(name)
      LogicalConstruct.register_platform(self)
      LogicalConstruct.require_platform_files(name, self)
    end
  end

  require_platform_files('default')
end

require 'logical-construct/target/platforms/virtualbox'
require 'logical-construct/target/platforms/aws'
