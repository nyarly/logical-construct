require 'rspec'
require 'file-sandbox'

require 'mock-resolve'
require 'cadre/rspec'

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.add_formatter(Cadre::RSpec::NotifyOnCompleteFormatter)
  config.add_formatter(Cadre::RSpec::QuickfixFormatter)
end
