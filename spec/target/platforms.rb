require 'logical-construct/target/platforms'

describe LogicalConstruct do
  after :each do
    ENV['LOGCON_DEPLOYMENT_PLATFORM'] = nil
    $DEPLOYMENT_PLATFORM = nil
  end

  describe "Platform()" do
    it "should fail for unset plaform" do
      expect do
        LogicalConstruct::Platform()
      end.to raise_error(KeyError)
    end

    it "should succeed for ENV VirtualBox" do
      ENV['LOGCON_DEPLOYMENT_PLATFORM'] = 'VirtualBox'
      LogicalConstruct::Platform().should == LogicalConstruct::VirtualBox
    end

    it "should succeed for global VirtualBox" do
      $DEPLOYMENT_PLATFORM = 'VirtualBox'
      LogicalConstruct::Platform().should == LogicalConstruct::VirtualBox
    end
  end

  describe "including VirtualBox" do
    before :each do
      ENV['LOGCON_DEPLOYMENT_PLATFORM'] = 'VirtualBox'
    end

    it "should make ChefConfig available" do
      LogicalConstruct::Platform()::ChefConfig.should == ::LogicalConstruct::VirtualBox::ChefConfig
    end
  end
end
