require 'logical-construct/target'


module TestAWS
  include LogicalConstruct
  include LogicalConstruct::Platform("AWS")

  describe "VirtualBox platform" do
    before :each do
      provision = Provision.new

      provision.in_namespace do
        resolution = ResolveConfiguration.new(provision)
        chef_config = ChefConfig.new(provision, resolution)
        chef_solo = ChefSolo.new(chef_config)
      end
    end

    it "should not crash" do
      true.should be_true
    end
  end
end

module TestVirtualBox
  include LogicalConstruct
  include LogicalConstruct::Platform("VirtualBox")

  describe "VirtualBox platform" do
    before :each do
      provision = Provision.new

      provision.in_namespace do
        resolution = ResolveConfiguration.new(provision)
        chef_config = ChefConfig.new(provision, resolution)
        chef_solo = ChefSolo.new(chef_config)
      end
    end

    it "should not crash" do
      true.should be_true
    end
  end

end
