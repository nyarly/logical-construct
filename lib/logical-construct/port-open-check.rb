module LogicalConstruct
  class TCPPortOpenCheck
    def initialize(port)
      @host = "localhost"
      @port = port
      @timeout = 0
      @retry_delay = 0.5
      yield self if block_given?
    end
    attr_accessor :host, :port
    attr_accessor :timeout, :retry_delay

    def open_socket
      TCPSocket.new @host, @port
    end

    def open?(timeout = nil)
      timeout ||= @timeout
      start_time = Time.now
      test_conn = open_socket()
      return true
    rescue Errno::ECONNREFUSED
      if Time.now - start_time > timeout
        return false
      else
        sleep @retry_delay
        retry
      end
    ensure
      test_conn.close if test_conn.respond_to? :close
    end

    def fail_if_open!
      raise "Port is open, should be closed: #{@host}:#{@port}" if open?(0)
    end

    def fail_if_closed!
      raise "Port is closed, should be open: #{@host}:#{@port}" unless open?
    end
  end
end
