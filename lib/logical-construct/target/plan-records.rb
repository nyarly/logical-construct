require 'fileutils'
require 'logical-construct/protocol'

module LogicalConstruct
  module ResolutionServer
    #Dirs:
    #Delivery destination
    #Local storage
    #Current plan archives
    #(Live unpacked plans)

    #clear existing plans
    #stash existing plans
    #wipe existing plan_dir
    #loop over nodes, creating plans for each

    #drive resolution on each? Long request if means e.g. pulling 200M
    #from S3...
    class PlanRecords
      include Enumerable

      Record = Struct.new(:name, :filehash)
      Directories = Struct.new(:delivered, :current, :stored)

      def initialize
        @records = []
        @directories = Directories.new(nil, nil, nil)
      end
      attr_reader :directories

      def reset!
        each do |record|
          record.cancel!
        end
        @records.clear
        clear_files(directories.delivered)
        clear_files(directories.current)
      end
      alias reset reset!

      def clear_files(directory)
        Pathname.new(directory).each_child do |delivered|
          delivered.delete
        end
      end

      def total_state
        return "no-plans-yet" if @records.empty?
        return "resolved" if @records.all?(:resolved?)
        return "unresolved"
      end

      def find(name)
        record = @records.find{|record| record.name == name}
      end

      def each(&block)
        @records.each(&block)
      end

      def add(name, hash)
        record = States::Unresolved.new(self, Record.new(name, hash))
        @records << record
        record.resolve
        record
      end

      def change(old_state, new_state_class)
        new_state = new_state_class.new(self, old_state.record)
        @records.delete(old_state)
        @records << new_state

        new_state.enter
        return new_state
      end
    end

    module States
      class PlanState
        include Protocol::PlanValidation
        include FileTest

        def initialize(records, record)
          @records, @record = records, record
        end
        attr_reader :record

        def inspect
          "#<#{self.class.name}:#{"0x%0x"%object_id} #{record.name}:#{record.filehash}>"
        end

        def ==(other)
          return (other.class.equal?(self.class) and
                  other.name.equal?(self.name) and
                  other.filehash.equal?(self.filehash))
        end


        def name
          @record.name
        end

        def filehash
          @record.filehash
        end

        def enter
        end

        def cancel!
        end

        def exists?(path)
          super(realpath(path))
        end

        def delivered_plans_dir
          @records.directories.delivered
        end

        def current_plans_dir
          @records.directories.current
        end

        def stored_plans_dir
          @records.directories.stored
        end

        def resolved?
          false
        end

        def can_receive?
          false
        end

        def change(next_state)
          @records.change(self, next_state)
        end

        def received_path
          @received_path ||= Pathname.new(delivered_plans_dir) + name
        end

        def storage_path_for(actual_hash)
          @stored_path ||= Pathname.new(stored_plans_dir) + [name, actual_hash].join(".")
        end

        def current_path
          @current_path ||= Pathname.new(current_plans_dir) + name
        end

        def resolve
          raise "Cannot resolve plan in current state: #{state}"
        end

        def receive
          raise "Cannot receive file in current state: #{state}"
        end

        def state
          self.class.name.sub(/.*::/,'').downcase
        end
      end

      class Unresolved < PlanState
        def can_receive?
          true
        end

        def store_received_file(actual_hash)
          stored_path = storage_path_for(actual_hash)
          unless exists?(stored_path)
            FileUtils.mv(received_path, stored_path)
            FileUtils.symlink(stored_path, received_path)
          end
        end

        def enter
          unless exists?(received_path)
            return false
          end

          actual_hash = file_checksum(received_path)

          store_received_file(actual_hash)

          if actual_hash == filehash
            FileUtils.cp(received_path.readlink, current_path.to_s)
            change(Resolved)
            return true
          else
            received_path.delete
            return false
          end
        end
        alias receive enter

        def resolve
          change(Resolving)
        end
      end

      class Resolving < PlanState
        def enter
          stored_path = storage_path_for(record.filehash)
          if exists?(stored_path) and not (exists?(received_path) or symlink?(received_path))
            FileUtils.symlink(stored_path, received_path)
          end
          change(Unresolved)
        end
      end

      class Resolved < PlanState
        def resolved?
          true
        end
      end
    end
  end
end
