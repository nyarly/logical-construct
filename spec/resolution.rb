require 'mattock/testing/rake-example-group'
require 'mattock/template-host'
require 'timeout'

require 'logical-construct/target/sinatra-resolver'
require 'logical-construct/ground-control/provision'
require 'logical-construct/satisfiable-task'

describe LogicalConstruct::SinatraResolver, :slow => true do
  include Mattock::RakeExampleGroup

  let :target_path do
    "target-file"
  end

  let :resolver_pipe do
    IO.pipe
  end

  let! :resolver_write do
    resolver_pipe[1]
  end

  let :resolver_read do
    resolver_pipe[0]
  end

  let :resolver_buffer do
    ""
  end

  let :resolver_process do
    Process.fork do
      extend Mattock::ValiseManager
      LogicalConstruct::SatisfiableFileTask.new(:target) do |task|
        task.target_path = target_path
      end

      LogicalConstruct::SinatraResolver.new(:resolver) do |task|
        task.valise = default_valise(File::expand_path("../../lib", __FILE__))
        task.bind = "127.0.0.1"
      end
      task :resolver => :target

      $stdout.reopen(resolver_write)
      $stderr.reopen(resolver_write)

      rake[:resolver].invoke
    end.tap do |pid|
      at_exit do
        kill("KILL", pid) rescue nil
      end
    end
  end


  before :each do
    resolver_process

    begin
      resolver_buffer << resolver_read.read_nonblock(4096)
    rescue IO::WaitReadable => err
      sleep 0.1
      retry
    end until /Listening on/ =~ resolver_buffer
  end

  after do
    begin
      Process.kill("INT", resolver_process)
      Process.wait(resolver_process)
    rescue => ex
      warn ex
    end
  end

  it "should block when unresolved" do
    expect do
      Process.wait(resolver_process, Process::WNOHANG)
    end.not_to raise_error
  end

  it "should not have a file already" do
    File::file?(target_path).should be_false
  end

  describe LogicalConstruct::GroundControl::Provision::WebConfigure do
    let :file_content do
      "Some test file content"
    end

    let! :web_configure do
      LogicalConstruct::GroundControl::Provision::WebConfigure.new(:web_configure) do |task|
        task.target_address = "127.0.0.1"
        task.resolutions["/target"] = proc{ file_content }
      end
    end

    before :each do
      rake[:web_configure].invoke
    end

    it "should complete resolver thread" do
      expect do
        begin
          Timeout::timeout(10) do
            Process.wait(resolver_process)
          end
        rescue Object => ex
          resolver_buffer << resolver.read_nonblock(10000) rescue ""
          p resolver_buffer
          raise
        end
      end.not_to raise_error
    end

    it "should produce the file" do
      File::read(target_path).should == file_content
    end
  end
end
