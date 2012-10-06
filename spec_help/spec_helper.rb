require 'rspec'
require 'file-sandbox'

require 'mock-resolve'
require 'timeout'

RSpec.configure do |rspec|
  rspec.around :each do |example|
    Timeout::timeout(3) do
      example.run
    end
  end
end
