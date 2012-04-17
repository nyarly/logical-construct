require 'logical-construct/target/chef-config'
require 'mattock/testing/rake-example-group'

describe LogicalConstruct::ChefConfig do
  include Mattock::RakeExampleGroup
  include FileSandbox

  before :each do
    sandbox.new :directory => "construct-dir"
    sandbox.new :directory => "chef-dir"
  end

  let :provision do
    require 'logical-construct/target/provision'
    LogicalConstruct::Provision.new do |prov|
      prov.construct_dir = "construct-dir"
    end
  end

  let! :chef_config do
    LogicalConstruct::ChefConfig.new(provision) do |cc|
      cc.file_cache_path = "chef-dir"
      cc.solo_rb = "chef-solo.rb"
    end
  end

  it "should make an absolute path for solo.rb" do
    chef_config.solo_rb.should =~ /\A\//
  end

  describe "invoked" do
    before :each do
      rake[File::join(sandbox["chef-dir"].path, "chef-solo.rb")].invoke
    end

    it "should generate the chef-solo.rb file" do
      sandbox["chef-dir/chef-solo.rb"].should be_exist
    end

    describe "resulting config file" do
      subject do
        sandbox["chef-dir/chef-solo.rb"].contents
      end

      it{ should =~ %r{file_cache_path\s*(["']).*\1} }
      it{ should =~ %r{cookbook_path\s*(["']).*/cookbooks\1} }
      it{ should =~ %r{json_attribs\s*(["']).*/node.json\1} }
      it{ should_not =~ /role_path/ }
    end

  end
end
