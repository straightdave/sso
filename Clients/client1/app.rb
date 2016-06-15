require 'sinatra'
require 'net/http'
require 'digest'

set :public_folder, File.dirname(__FILE__) + '/src'

get '/' do
  erb :homepage
end

#callback url
get '/sso_callback' do
  # get ticket
  ticket = params["ticket"]
  who = params["who"]

  # call SSO API with ticket
  # refer to http://ruby-doc.org/stdlib-2.3.1/libdoc/net/http/rdoc/Net/HTTP.html
  uri = URI("http://localhost:8001/check/#{ticket}")
  resp = Net::HTTP.start(uri.host, uri.port) do |http|
    request = Net::HTTP::Get.new uri
    # add header
    request["x-appkey"] = "appkey1"
    request["x-mac"] = Digest::MD5.hexdigest("/check/#{ticket}_skey1")
    request["x-who"] = who
    http.request request
  end


  # get user info from response
  body = resp.body
  # login user in client

  # redirect to certain page

end
