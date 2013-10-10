require 'logical-construct/node-client'
require 'logical-construct/target/resolution-server'

require 'roadforest/test-support'

describe LogicalConstruct::NodeClient do
  let :destination_dir do
    "spec_help/fixtures/destination"
  end

  let :source_dir do
    "spec_help/fixtures/source"
  end

  let :services do
    LogicalConstruct::ResolutionServer::ServicesHost.new.tap do |services|
      services.plan_records.directories.tap do |dirs|
        dirs.delivered = File::join(destination_dir, "delivered")
        dirs.current = File::join(destination_dir, "current")
        dirs.stored = File::join(destination_dir, "stored")
      end
    end
  end

  let :plan_archives do
    %w{one two three}.map do |name|
      "#{source_dir}/#{name}.tbz"
    end
  end

  let :server do
    RoadForest::TestSupport::RemoteHost.new(
      LogicalConstruct::ResolutionServer::Application.new("http://logical-construct-resolution.com/", services)
    )
  end

  let :node_client do
    LogicalConstruct::NodeClient.new.tap do |client|
      client.server = server
      client.plan_archives = plan_archives
      #client.server.graph_transfer.trace = true
    end
  end

  before :each do
    require 'fileutils'
    FileUtils.rm_rf(destination_dir)
    FileUtils.mkdir_p(destination_dir)
  end

  it "should get a resolution state" do
    node_client.state.should == 'no-plans-yet'
  end

  it "should completely deliver a manifest" do
    node_client.deliver_manifest
    node_client.state.should == "unresolved"
    node_client.deliver_plans
    node_client.state.should == "resolved"
  end
end
