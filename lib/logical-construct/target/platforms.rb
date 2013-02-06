module LogicalConstruct
  def self.platforms
    @platforms ||= {}
  end

  def self.register_platform(mod)
    name = mod.name.split('::').last
    platforms[name] = mod
  end

  PLATFORM_FILES = %w{volume chef-config resolve-configuration bake bake-system}
  PLATFORM_MODULES = [:Volume, :ChefConfig, :ResolveConfiguration, :Bake, :BakeSystem]

  def self.require_platform_files(platform, mod)
    missing_files = []
    PLATFORM_FILES.each do |file|
      begin
        require File::join('logical-construct', 'target', 'platforms', platform, file)
      rescue LoadError
        missing_files << file
      end
    end

    undefined_modules = []
    PLATFORM_MODULES.each do |name|
      unless mod.const_defined?(name)
        default_klass = LogicalConstruct::Default.const_get(name)
        raise NameError, "Missing default platform class LogicalConstruct::Default::#{name}"
        klass = Class.new(default_klass)
        mod.const_set(name, klass)
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

  module Default
  end

  require_platform_files('default', Default)
end

require 'logical-construct/target/platforms/virtualbox'
require 'logical-construct/target/platforms/aws'
