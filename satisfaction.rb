require 'logical-construct/satisfiable-task'
require 'logical-construct/target/sinatra-resolver'

file = LogicalConstruct::SatisfiableFileTask.define_task do |file|
  file.task_name = "testfile"
  file.target_path = "satisfaction-test/a_file"
end

directory "satisfaction-test"
task :testfile => "satisfaction-test"

env = LogicalConstruct::SatisfiableEnvTask.define_task do |env|
  env.task_name = "testenv"
  env.target_name = "LOGCON_TESTING"
end

manifest = LogicalConstruct::Manifest.define_task(file)

require 'mattock/template-host'
include Mattock::ValiseManager
res = LogicalConstruct::SinatraResolver.define_task(manifest, file, env) do |res|
  res.task_name = "resolve"
  res.valise = default_valise("lib")
end

manifester = LogicalConstruct::GenerateManifest.define_task(:make_manifest) do |manifest|
  manifest.paths["satisfaction-test/a_file"] = "satisfaction-test/source_file"
end

task :print_manifest => :make_manifest do
  puts manifester.task.manifest
end

task :default => [:print_manifest, :testfile, :testenv] do
  puts "Finished"
  puts "ENV[LOGCON_TESTING] = #{ENV["LOGCON_TESTING"]}"
  puts %x{ls satisfaction-test}
  puts %x{cat satisfaction-test/a_file}
end
