require 'sinatra'
require 'net/http'
require 'digest'
require 'json'
require_relative 'helpers'

set :port, 8011
set :public_folder, File.dirname(__FILE__) + '/src'
use Rack::Session::Pool, :expire_after => 2592000

get '/' do
  @login_user_name = session[:user_name] if login?
  erb :homepage
end

get '/company' do
  erb :company
end

#callback url
get '/sso_callback' do

  # get params
  act    = params["act"]
  ticket = params["ticket"] # could be nil
  who    = params["who"] # could be nil

  if act == "logout"
    session.destroy
    redirect to("/")
  end

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
  user = JSON.parse(body)

  # login user in client
  session[:user_id] = user["account"]["id"]
  session[:user_name] = user["account"]["name"]

  # redirect to certain page
  redirect to("/")
end

get '/show_session' do
  "this app's session: id=#{session[:user_id]}, name=#{session[:user_name]}"
end
