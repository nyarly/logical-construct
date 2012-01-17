Gem::Specification.new do |spec|
  spec.name		= "logical-construct"
  spec.version		= "0.0.1"
  author_list = {
    "Judson Lester" => "nyarly@gmail.com"
  }
  spec.authors		= author_list.keys
  spec.email		= spec.authors.map {|name| author_list[name]}
  spec.summary		= "Works with Fog and Virtualbox and Chef to build servers"
  spec.description	= <<-EndDescription
  Like Vagrant?  Missing AWS?  Here you go.  Limited Rakefiles to do that.
  EndDescription

  spec.rubyforge_project= spec.name.downcase
  spec.homepage        = "http://#{spec.rubyforge_project}.rubyforge.org/"
  spec.required_rubygems_version = Gem::Requirement.new(">= 0") if spec.respond_to? :required_rubygems_version=

  # Do this: y$@"
  # !!find lib bin doc spec spec_help -not -regex '.*\.sw.' -type f 2>/dev/null
  spec.files		= %w[
    lib/logical-construct/target.rb
    lib/logical-construct/parent/setup.rb
    lib/logical-construct/target/provision.rb
    lib/logical-construct/target/chef-solo.rb
    lib/logical-construct/target/build-attributes.rb
    lib/logical-construct/target/unpack-cookbook.rb
    lib/logical-construct/parent.rb
    lib/templates/Gemfile.erb
    lib/templates/Rakefile.erb
    doc/README
    spec_help/spec_helper.rb
    spec_help/gem_test_suite.rb
    spec_help/ungemmer.rb
    spec_help/file-sandbox.rb
  ]

  spec.test_file        = "spec_help/gem_test_suite.rb"
  spec.licenses = ["MIT"]
  spec.require_paths = %w[lib/]
  spec.rubygems_version = "1.3.5"

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

  #spec.add_dependency("postgres", ">= 0.7.1")
  spec.add_dependency("mattock", "> 0")

  spec.post_install_message = "Another tidy package brought to you by Judson"
end
