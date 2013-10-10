require 'logical-construct/ground-control'
require 'mattock/testing/rake-example-group'

module LogicalConstruct::GroundControl
  describe "An example Rakefile" do
    include Mattock::RakeExampleGroup
    include LogicalConstruct::GroundControl

    before :each do

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
