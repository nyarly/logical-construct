require 'logical-construct/target/flight-deck'
require 'mattock/testing/rake-example-group'

module LogicalConstruct::GroundControl
  describe "An example Rakefile" do
    include Mattock::RakeExampleGroup

    before :each do
      LogicalConstruct::Target::FlightDeck.new
    end

    it "should load without error" do
      true.should be_true #oo be doo be doo
    end
  end
end
