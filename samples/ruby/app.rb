require "sinatra"
require "json"

set :port, ENV.fetch("PORT", 8080).to_i
set :bind, "0.0.0.0"

get "/" do
  "Hello from distroless buildpack builder!"
end

get "/health" do
  content_type :json
  { status: "OK" }.to_json
end
