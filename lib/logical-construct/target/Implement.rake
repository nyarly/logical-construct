require 'logical-construct/target/implementation.rb'

include LogicalConstruct::Target

impl = Implementation.new do
end

task :default => impl[:complete]
