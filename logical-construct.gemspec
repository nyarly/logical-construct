Gem::Specification.new do |spec|
  spec.name		= "logical-construct"
  spec.version		= "0.1.0"
  author_list = {
    "Judson Lester" => "nyarly@gmail.com"
  }
  spec.authors		= author_list.keys
  spec.email		= spec.authors.map {|name| author_list[name]}
  spec.summary		= "Works with Fog and Virtualbox and Chef to build servers"
  spec.description	= <<-EndDescription
  Like Vagrant?  Missing AWS?  Here you go.  Limited Rakefiles to do something like that.
  EndDescription

  spec.rubyforge_project= spec.name.downcase
  spec.homepage        = "http://#{spec.rubyforge_project}.rubyforge.org/"
  spec.required_rubygems_version = Gem::Requirement.new(">= 0") if spec.respond_to? :required_rubygems_version=

  # Do this: y$@"
  # !!find lib bin doc spec spec_help -not -regex '.*\.sw.' -type f 2>/dev/null
  spec.files		= %w[
    lib/logical-construct/plan/core.rb
    lib/logical-construct/plan/standalone-bundle.rb
    lib/logical-construct/template-file.rb
    lib/logical-construct/node-client.rb
    lib/logical-construct/port-open-check.rb
    lib/logical-construct/ground-control.rb
    lib/logical-construct/archive-tasks.rb
    lib/logical-construct/target.rb
    lib/logical-construct/target/plan-records.rb
    lib/logical-construct/target/unpack-plan.rb
    lib/logical-construct/target/Implement.rake
    lib/logical-construct/target/command-line.rb
    lib/logical-construct/target/implementation.rb
    lib/logical-construct/target/flight-deck.rb
    lib/logical-construct/target/resolution-server.rb
    lib/logical-construct/ground-control/core.rb
    lib/logical-construct/ground-control/run-on-target.rb
    lib/logical-construct/ground-control/setup/copy-files.rb
    lib/logical-construct/ground-control/provision.rb
    lib/logical-construct/ground-control/build-plan.rb
    lib/logical-construct/ground-control/generate-manifest.rb
    lib/logical-construct/ground-control/tools.rb
    lib/logical-construct/ground-control/setup.rb
    lib/logical-construct/protocol.rb
    lib/logical-construct/protocol/ssh-tunnel.rb
    lib/logical-construct/protocol/node-client.rb
    lib/logical-construct/protocol/vocabulary.rb
    lib/logical-construct/protocol/plan-validation.rb
    lib/logical-construct/plan.rb
    lib/templates/Gemfile.erb
    lib/templates/Rakefile.erb
    bin/flight-deck
    doc/TODO
    doc/DESIGN
    spec/node_resolution.rb
    spec/target/plan-records.rb
    spec/target/provisioning.rb
    spec/ground-control/smoke-test.rb
    spec_help/spec_helper.rb
    spec_help/gem_test_suite.rb
    spec_help/fixtures/Manifest
    spec_help/fixtures/source/three.tbz
    spec_help/fixtures/source/two.tbz
    spec_help/fixtures/source/one.tbz
    spec_help/mock-resolve.rb
    spec_help/file-sandbox.rb
  ]

  spec.test_file        = "spec_help/gem_test_suite.rb"
  spec.licenses = ["MIT"]
  spec.require_paths = %w[lib/]
  spec.rubygems_version = "1.3.5"
  spec.executables = %w{flight-deck}

  if spec.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    spec.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      spec.add_development_dependency "corundum", "~> 0.0.1"
    else
      spec.add_development_dependency "corundum", "~> 0.0.1"
    end
  else
    spec.add_development_dependency "corundum", "~> 0.0.1"
  end

  spec.has_rdoc		= true
  spec.extra_rdoc_files = Dir.glob("doc/**/*")
  spec.rdoc_options	= %w{--inline-source }
  spec.rdoc_options	+= %w{--main doc/README }
  spec.rdoc_options	+= ["--title", "#{spec.name}-#{spec.version} RDoc"]

  spec.add_dependency("rake", "~> 10.0")
  spec.add_dependency("mattock", "~> 0.5")
  spec.add_dependency("roadforest", "~> 0.0.2")

  spec.add_dependency("multipart-parser",">= 0.1.1")
  spec.add_dependency("nokogiri", ">= 0.13.4")
  spec.add_dependency("json")
end
