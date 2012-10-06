require 'logical-construct/target/chef-solo'
require 'logical-construct/target/platforms'
require 'mattock/testing/rake-example-group'
require 'mattock/testing/mock-command-line'

describe LogicalConstruct::ChefSolo do
  include Mattock::RakeExampleGroup
  include FileSandbox

  let :provision do
    require 'logical-construct/target/provision'
    LogicalConstruct::Provision.new
  end

  let :resolver do
    require 'logical-construct/testing/resolve-configuration'
    LogicalConstruct::Testing::ResolveConfiguration.new(provision)
  end

  let! :chef_config do
    LogicalConstruct::VirtualBox::ChefConfig.new(provision, resolver) do |cc|
      cc.file_cache_path = "chef-dir"
      cc.solo_rb = "chef-solo.rb"
      cc.cookbooks = []
    end
  end

  let! :chef_solo do
    LogicalConstruct::ChefSolo.new(chef_config)
  end

  describe "invoked" do
    include Mattock::CommandLineExampleGroup

    it "should run chef-solo" do
      expect_command /chef-solo/, ""

      rake["chef_solo:run"].invoke
    end
  end
end
