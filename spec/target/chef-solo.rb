require 'logical-construct/target/chef-solo'
require 'logical-construct/target/platforms'
require 'mattock/testing/rake-example-group'
require 'mattock/testing/mock-command-line'

describe LogicalConstruct::ChefSolo, :pending => "Changeover to new provisioning" do
  include Mattock::RakeExampleGroup
  include FileSandbox

  let :provision do
    require 'logical-construct/target/provision'
    LogicalConstruct::Provision.new
  end

  let :resolver do
    require 'logical-construct/testing/resolve-configuration'
    LogicalConstruct::Testing::ResolveConfiguration.new(provision) do |resolve|
      resolve.resolutions = {
        'chef_config:cookbook_tarball' => '',
        'chef_config:json_attribs' => '',
      }
    end
  end

  let! :chef_config do
    LogicalConstruct::VirtualBox::ChefConfig.new(provision, resolver) do |cc|
      cc.file_cache_path = "chef-dir"
      cc.solo_rb = "chef-solo.rb"
    end
  end

  let! :chef_solo do
    LogicalConstruct::ChefSolo.new(chef_config)
  end

  describe "invoked" do
    include Mattock::CommandLineExampleGroup

    it "should have the bundle path in the PATH" do
      expect_some_commands
      rake["chef_solo:run"].invoke
      ENV['PATH'].should =~ %r{/opt/logical-construct/bin}
    end

    it "should run chef-solo" do
      Rake.verbose(true)
      expect_command /tar/, 0
      expect_command /tar/, 0
      expect_command /tar/, 0
      expect_command /chef-solo/, 0

      rake["chef_solo:run"].invoke
    end
  end
end
