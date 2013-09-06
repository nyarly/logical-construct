require 'logical-construct/target/plan-records'
require 'logical-construct/protocol/plan-validation'
require 'file-sandbox'

module LogicalConstruct::ResolutionServer
  describe LogicalConstruct::ResolutionServer::PlanRecords do
    include FileSandbox

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
      records.find("not there").should be_nil
    end

    it "should add a record" do
      record = records.add("test", "000000")
      record.should_not be_nil
      records.count.should == 1
      records.find("test").should == record
    end

    describe "single record" do
      include LogicalConstruct::Protocol::PlanValidation

      let! :file do
        sandbox.new :file => "delivered/test", :with_contents => file_contents
      end

      let :file_contents do
        "A test file - hello!"
      end

      let :filehash do
        file_checksum(file.path)
      end

      it "should receive a new file" do
        record = records.add("test", filehash)
        record.resolve
        record.receive
        File.read("current/test").should == file_contents
        File.exists?(file.path).should be_false
      end

      it "should reject a bad file" do
        record = records.add("test", "00000000")
        record.receive

        File.exists?("current/test").should be_false
        File.exists?(file.path).should be_false
      end

      it "should reject new files when resolved" do
        record = records.add("test", filehash)
        record.receive

        File.read(File.readlink(file.path)).should == file_contents
        record = records.find("test")
        expect{record.receive}.to raise_error
      end

      it "should reset properly" do
        record = records.add("test", filehash)
        record.receive

        records.reset!

        Dir["delivered/*"].should be_empty
        Dir["current/*"].should be_empty
        records.find("test").should be_nil
      end

      it "should resolve an old file" do
        record = records.add("test", filehash)
        record.receive

        records.reset!

        File.exists?(file.path).should be_false

        record = records.add("test", filehash)
        record.resolve

        File.read("current/test").should == file.contents
        File.exists?(file.path).should be_false
      end
    end
  end
end
