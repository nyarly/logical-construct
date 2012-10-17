module LogicalConstruct
  module Testing
    def self.stub_resolution(resolver, fulfillment)
      resolver.instance_eval do
        define_method :action do
          fulfillment.each_pair do |key, value|
            prereq = prerequisite_tasks.find do |task|
              task.name == key
            end

            if prereq.nil?
              raise "No prerequisite task named #{key}"
            else
              prereq.fulfill(value)
            end
          end
        end
      end
    end
  end
end
