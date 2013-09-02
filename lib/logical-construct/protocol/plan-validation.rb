require 'openssl'
module LogicalConstruct
  module Protocol
    module PlanValidation
      class DigestFailure < ::StandardError; end

      def digest
        @digest ||= OpenSSL::Digest::SHA256.new
      end

      def check_digest(checksum, path, target_path=nil)
        if file_checksum(path) != checksum
          raise DigestFailure, "Digest failure for #{target_path || path}"
        end
      end

      #The biggest digest-block-length-aligned chunk under 4MB
      BIG_CHUNK = 4 * 1024 * 1024
      def chunk_size
        @chunk_size ||= (BIG_CHUNK / digest.block_length).floor * digest.block_length
      end

      def realpath(path)
        File::readlink(path.to_s)
      rescue Errno::EINVAL, Errno::ENOENT
        path
      end

      def file_checksum(path)
        digest.reset
        File::open(realpath(path)) do |file|
          while chunk = file.read(chunk_size)
            digest.update(chunk)
          end
        end
        digest.hexdigest
      end

      def generate_checksum(data)
        digest.reset
        digest << data
        digest.hexdigest
      end
    end
  end
end
