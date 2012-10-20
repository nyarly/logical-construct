require 'logical-construct/satisfiable-task'
require 'logical-construct/target/sinatra-resolver'

file = LogicalConstruct::SatisfiableFileTask.new do |file|
  file.task_name = "testfile"
  file.target_path = "satisfaction-test/a_file"
end

directory "satisfaction-test"
task :testfile => "satisfaction-test"

env = LogicalConstruct::SatisfiableEnvTask.new do |env|
  env.task_name = "testenv"
  env.target_name = "LOGCON_TESTING"
end

require 'mattock/template-host'
include Mattock::ValiseManager
res = LogicalConstruct::SinatraResolver.new do |res|
  res.task_name = "resolve"
  res.valise = default_valise("lib")
end

task :resolve => [:testfile, :testenv]

task :default => :resolve do
  puts "Finished"
  puts "ENV[LOGCON_TESTING] = #{ENV["LOGCON_TESTING"]}"
  puts %x{ls satisfaction-test}
  puts %x{cat satisfaction-test/a_file}
end
