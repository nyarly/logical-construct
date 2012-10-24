require 'logical-construct/ground-control'

module LogicalConstruct::GroundControl
  describe "An example Rakefile" do

    before :each do
      extend LogicalConstruct::GroundControl
      core = Core.new

      setup = Setup.new(core)
      setup.default_subtasks

      provision = Provision.new(core) do |prov|
        prov.marshalling_path = "marshall"
      end
    end

    it "should load without error" do
      true.should be_true #oo be doo be doo
    end

  end
end
