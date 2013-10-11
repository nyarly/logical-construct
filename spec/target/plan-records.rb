require 'logical-construct/target/plan-records'
require 'logical-construct/protocol/plan-validation'
require 'file-sandbox'

module LogicalConstruct::ResolutionServer
  describe LogicalConstruct::ResolutionServer::PlanRecords do
    include FileSandbox

    before :all do
      @original_verbose = $VERBOSE
      $VERBOSE = nil
    end

    after :all do
      $VERBOSE = @original_verbose
    end

    before :each do
      sandbox.new :directory => "delivered"
      sandbox.new :directory => "current"
      sandbox.new :directory => "stored"
    end

    let :records do
      PlanRecords.new.tap do |records|
        records.directories.delivered = "delivered"
        records.directories.current = "current"
        records.directories.stored = "stored"
      end
    end

    it "should not find absent records" do
      records.total_state.should == "no-plans-yet"
      records.find("not there").should be_nil
    end

    it "should add a record" do
      record = records.add("test", "000000")
      record.should_not be_nil
      records.count.should == 1
      record = records.find("test")
      record.join
      record = records.find("test")
      record.state.should == "unresolved"
      record.name.should == "test"
      record.filehash.should == "000000"
      records.total_state.should == "unresolved"
    end

    it "should reject a duplicate add" do
      record = records.add("test", "000000")
      expect do
        records.add("test", "000000")
      end.to raise_error

      expect do
        records.add("test", "ffffff")
      end.to raise_error
    end

    describe "single record" do
      include LogicalConstruct::Protocol::PlanValidation

      let! :file do
        sandbox.new :file => "just_hanging_out/test", :with_contents => file_contents
      end

      let :file_contents do
        "A test file - hello!"
      end

      let :filehash do
        file_checksum(file.path)
      end

      it "should receive a new file" do
        record = records.add("test", filehash)
        record.join

        sandbox.new :file => "delivered/test", :with_contents => file_contents

        record = records.find("test")
        record.receive.should be_a(LogicalConstruct::ResolutionServer::States::PlanState)
        File.read("current/test").should == file_contents
        File.exists?("delivered/test").should be_false
        records.total_state.should == "resolved"
      end

      it "should reject a bad file" do
        record = records.add("test", "00000000")
        record.receive

        File.exists?("current/test").should be_false
        File.exists?("delivered/test").should be_false
      end

      it "should reject new files when resolved" do
        record = records.add("test", filehash)
        record.join

        sandbox.new :file => "delivered/test", :with_contents => file_contents
        records.find("test").receive

        File.read(File.readlink("delivered/test")).should == file_contents
        record = records.find("test")
        expect(record.receive).to be_false
      end

      it "should reset properly" do
        record = records.add("test", filehash)
        sandbox.new :file => "delivered/test", :with_contents => file_contents
        record.receive

        records.reset!

        Dir["delivered/*"].should be_empty
        Dir["current/*"].should be_empty
        records.find("test").should be_nil
      end

      it "should resolve an old file" do
        record = records.add("test", filehash)
        record.join
        record = records.find("test")

        sandbox.new :file => "delivered/test", :with_contents => file_contents
        record.receive

        records.reset!

        File.exists?("delivered/test").should be_false

        record = records.add("test", filehash)
        records.find("test").join

        File.read("current/test").should == file.contents
        File.exists?("delivered/test").should be_false
        record.resolve.should be_false
      end
    end
  end
end
