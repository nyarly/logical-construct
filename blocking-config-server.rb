require 'sinatra'
require 'json'


set :show_exceptions => true

get '/' do
  'Ready and waiting'
end

put '/user-data' do
  request.body.rewind
  data = JSON.parse request.body.read
  p data
  File::open("/tmp/user-data", "w") do |f|
    request.body.rewind
    f.write(request.body.read)
  end
  "Okay, thanks"
  Process::kill(:INT, Process::pid)
end
