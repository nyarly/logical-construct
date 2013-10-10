require 'logical-construct/ground-control'

module LogicalConstruct::GroundControl
  describe "An example Rakefile" do

    before :each do
      include LogicalConstruct::GroundControl

      namespace :example do
        provision = Provision.new
        provision.plans("test")
      end

      tools = Tools.new
    end

    it "should load without error" do
      true.should be_true #oo be doo be doo
    end

  end
end
