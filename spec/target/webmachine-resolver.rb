require 'webmachine/test'
require 'logical-construct/target/webmachine-resolver'
require 'mida'
require 'rest-client'
require 'atst'
require 'forwardable'

Construct = RDF::Vocabulary.new("http://lrdesign.com/logical-construct/microdata#")

class WebmachineTestWrapper
  def initialize(session)
    @session = session
  end

  def get(uri)
    @session.get(uri)
    return HTTPTransaction.new(@session.request, @session.response)
  end

  class HTTPTransaction
    extend Forwardable

    def initialize(req, res)
      @request = req
      @response = res
    end

    def content_type
      @response.headers["Content-Type"]
    end

    def_delegators :@request, :uri
    def_delegators :@response, :code

    def body
      @body ||= StringIO.new(@response.body)
    end
  end
end

describe LogicalConstruct::WebmachineResolver do
  include Webmachine::Test
  include FileSandbox

  let :walker do
    ATST::Walker.new.tap do |walker|
      walker.http_client = WebmachineTestWrapper.new(current_session)
    end
  end

  def needs(uri)
    walker.get(uri)
    walker.query do
      pattern [:need, Construct.deliver_to, :deliver_to]
      pattern [:need, Construct.requirement, :requirement]
      pattern [:need, Construct.signature, :signature]
      pattern [:need, Construct.status, :status]
      pattern [:need, :type, Construct.need ]
    end
  end

  def need(uri, path)
    walker.get(uri)
    walker.query do
      pattern [:need, Construct.deliver_to, :deliver_to]
      pattern [:need, Construct.requirement, path]
      pattern [:need, Construct.signature, :signature]
      pattern [:need, Construct.status, :status]
      pattern [:need, :type, Construct.need ]
    end.first
  end

  let :test_valise do
    Valise.define do
      ro from_here("../../lib", up_to("spec"))
    end
  end

  let :app do
    resolver = LogicalConstruct::WebmachineResolver.new
    resolver.valise = test_valise
    resolver.model.provisioning_directory = "test_provision"
    resolver.build_app
  end

  before :each do
    @sandbox.new :directory => "test_provision"
  end

  shared_examples "for an unresolved need" do
    describe "in /needs" do
      it "should succeed" do
        needs("/needs")
        response.code.should == 200
      end

      it "should be 'unresolved'" do
        need("/needs", "Manifest")["status"].to_s.should == "unresolved"
      end
    end

    describe "in /resolved-needs" do
      it "should succeed" do
        needs("/resolved-needs")
        response.code.should == 200
      end

      it "should not be present" do
        need("/resolved-needs", "Manifest").should be_nil
      end
    end

    describe "in /unresolved-needs" do
      it "should succeed" do
        needs("/unresolved-needs")
        response.code.should == 200
      end

      it "should be present" do
        need("/unresolved-needs", "Manifest").to_hash.should_not be_nil
      end
    end
  end

  shared_examples "for a resolved need" do
    describe "in /needs" do
      it "should succeed" do
        needs("/needs")
        response.code.should == 200
      end

      it "should be 'unresolved'" do
        need("/needs", "Manifest")["status"].to_s.should == "resolved"
      end
    end

    describe "in /resolved-needs" do
      it "should succeed" do
        needs("/resolved-needs")
        response.code.should == 200
      end

      it "should be present" do
        need("/resolved-needs", "Manifest").to_hash.should_not be_nil
      end
    end

    describe "in /unresolved-needs" do
      it "should succeed" do
        needs("/unresolved-needs")
        response.code.should == 200
      end

      it "should not be present" do
        need("/unresolved-needs", "Manifest").should be_nil
      end
    end
  end

  describe "/" do
    before :each do
      get "/"
    end

    it "should succeed" do
      response.code.should == 200
    end

    it "should have a URL" do
      #puts response.body
      response.body.should =~ %r{a[^>]*href=[^>*]/needs}i
    end
  end

  describe "/provisioning-status" do
    it "should succeed" do
      get "/provisioning-status"
      response.code.should == 200
    end

    it "should reflect last status that was PUT" do
      header("Content-Type", "application/x-www-form-urlencoded")
      body URI::encode_www_form("status" => "testing")
      put "/provisioning-status"

      get "/provisioning-status"

      response.body.should =~ /testing/


        header("Content-Type", "application/x-www-form-urlencoded")
      body URI::encode_www_form("status" => "different")
      put "/provisioning-status"

      get "/provisioning-status"

      response.body.should_not =~ /testing/
        response.body.should =~ /different/
    end

    it "should update last polling time" do
      expect do
        get "/unresolved-needs"
        response.code.should == 200
      end.to change{
        get "/provisioning-status"
        doc = Mida::Document.new(response.body, request.uri.to_s)
        doc.first.properties["last-poll"]
      }
    end
  end

  describe "/needs" do
    it "should succeed with an empty list" do
      get "/needs"
      response.code.should == 200
      doc = Mida::Document.new(response.body)
      needs = doc.search %r{http://lrdesign.com/logical-construct/microdata#need}
      needs.should be_empty
    end

    it "should return needs from previous posts" do
      header("Content-Type", "application/x-www-form-urlencoded")
      body URI::encode_www_form("path" => "Manifest", "signature" => "")
      put "/needs"

      get "/needs"

      response.code.should == 200
      doc = Mida::Document.new(response.body, request.uri.to_s)

      needs = doc.search %r{http://lrdesign.com/logical-construct/microdata#need}
      needs.should_not be_empty
      needs.first.properties["requirement"].first.should == "Manifest"
      needs.first.properties["deliver_to"].first.should =~ %r{/needs.*Manifest}
    end
  end

  describe "/unresolved-needs" do
    it "should succeed with an empty list" do
      get "/unresolved-needs"
      response.code.should == 200
      doc = Mida::Document.new(response.body)
      needs = doc.search %r{http://lrdesign.com/logical-construct/microdata#need}
      needs.should be_empty
    end


  end

  describe "/resolved-needs" do
    it "should succeed with an empty list" do
      get "/resolved-needs"
      response.code.should == 200
      doc = Mida::Document.new(response.body)
      needs = doc.search %r{http://lrdesign.com/logical-construct/microdata#need}
      needs.should be_empty
    end


  end

  describe "/needs/[file]" do
    describe "a need without verification signature" do
      let :needed_path do
        "Manifest"
      end

      let :need_stream do
        File::open("../spec_help/fixtures/Manifest")
      end

      after :each do
        need_stream.close unless need_stream.closed?
      end

      before :each do
        header("Content-Type", "application/x-www-form-urlencoded")
        body URI::encode_www_form("path" => needed_path, "signature" => "")
        put "/needs"
      end

      include_context "for an unresolved need"

      it "should succeed for existing needs" do
        get need("/needs", "Manifest")["deliver_to"]
        response.code.should == 200
      end

      describe "once provided" do
        before :each do
          payload = RestClient::Payload.generate(:file => need_stream)
          payload.headers.each do |name, value|
            header(name, value)
          end

          body [payload.to_s]
          post need("/needs", "Manifest")["deliver_to"]
        end

        include_context "for a resolved need"
      end
    end

    it "should report 404 for non-existent needs" do
      get "/needs/dont-exist"
      response.code.should == 404
    end
  end
end
