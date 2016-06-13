require 'sinatra'
require 'active_record'
require 'securerandom'
require 'sinatra/cookies'
require_relative 'models/account'
require_relative 'models/client'

use Rack::Session::Pool, :expire_after => 2592000

ActiveRecord::Base.establish_connection(
  :adapter  => "mysql2",
  :host     => "localhost",
  :username => "dave",
  :password => "123123",
  :database => "sso"
)
ActiveRecord::Base.default_timezone = :local

after do
  ActiveRecord::Base.connection.close
end

# routers
get '/' do
  redirect to("/account/login?from=_home")
end

get '/account/login' do
  halt 451, "err: from nowhere" unless client_key = params["from"]
  halt 452, "err: wrong app" unless @client = Client.find_by_appkey(client_key)

  session[:proc_expire] = (Time.now + (5 * 60)).getutc
  session[:proc_code] = SecureRandom.uuid
  session[:proc_step] = "initlogin"

  # if already logged on, go client's callback asap
  if who = cookies[:who] &&
     account = Account.find_by(id: who) &&
     account.apps.exists?(@client.id) &&
     session[:account_id] == who
    session[:proc_step] = "loggedin"
    # already have :proc_expire and :proc_code for checking
    redirect to(client.callback_url + "?who=#{who}&ticket=#{session[:proc_code]}")
  end

  erb :login
end

post '/account/login' do
  halt 451, "err: from nowhere" unless client_key = params["from"]
  halt 452, "err: wrong app" unless client = Client.find_by_appkey(client_key)

  # validate form
  halt 453, "err: no form code" unless code = params["code"]
  halt 453, "err: wrong form code" unless code == session[:proc_code]
  halt 454, "err: form timeout" unless Time.now.getutc < session[:proc_expire]

  # validate account
  halt 455, "err: no name" unless name = params["name"]
  halt 455, "err: no pass" unless pass = params["pass"]
  halt 456, "err: wrong name" unless account = Account.find_by_name(name)
  halt 459, "err: no access" unless account.apps.exists?(client.id)
  halt 456, "err: wrong password" unless account.password == pass

  # login user
  session[:account_name] = name
  session[:account_id] = account.id
  session[:account_apps] = account.app_ids.join('_')

  # reset proc session
  session[:proc_code] = SecureRandom.uuid # new uuid for check
  session[:proc_expire] = (Time.now + (5 * 60)).getutc
  session[:proc_step] = "loggedin"

  # set persona cookie
  # SECURTY NEED
  cookies[:who] = account.id

  # redirect to callback url
  who = account.id
  redirect to(client.callback_url + "?who=#{who}&ticket=#{session[:proc_code]}")
end

# every time redirect to client's callback_url,
# client will call this api
# this API should be validated
get '/check/:ticket' do |ticket|
  # check API access
  # HEADER NEED
  halt 460, "err: no header: appkey" unless header_appkey = request["x-appkey"]
  halt 460, "err: no header: mac" unless header_mac = request["x-mac"]
  halt 461, "err: wrong mac" unless header_mac == client.build_mac(request.path)

  # NEED WHO cookie
  halt 452, "err: wrong app" unless client = Client.find_by_appkey(header_appkey)
  halt 462, "err: no who" unless who = params["who"]
  halt 456, "err: wrong id" unless account = Account.find_by(id: who)
  halt 459, "err: no access" unless account.apps.exists?(client.id)

  halt 463, "err: wrong step" unless session[:proc_step] == "loggedin"
  halt 454, "err: ticket timeout" unless Time.now.getutc < session[:proc_expire]
  halt 463, "err: wrong ticket" unless ticket == session[:proc_code]

  # finish proc
  session[:proc_expire] = nil
  session[:proc_step] = nil
  session[:proc_code] = nil

  # return whether logged in
  if session[:account_id] == who &&
     session[:account_name] == account.name
    "true"
  else
    "false"
  end
end

get '/reset' do
  session.destroy
end
