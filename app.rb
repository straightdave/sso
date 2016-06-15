require 'sinatra'
require 'sinatra/json'
require 'json'
require 'redis'
require 'active_record'
require 'securerandom'
require 'sinatra/cookies'
require_relative 'models/account'
require_relative 'models/client'
require_relative 'helpers'

use Rack::Session::Pool, :expire_after => 2592000
set :port, 8001

ActiveRecord::Base.establish_connection(
  :adapter  => "mysql2",
  :host     => "localhost",
  :username => "dave",
  :password => "123123",
  :database => "sso"
)
ActiveRecord::Base.default_timezone = :local

before do
  unless @redis = Redis.new(:host => "localhost", :port => 6379, :db => 5)
    halt 469, "err: redis not ok"
  end
end

after do
  ActiveRecord::Base.connection.close
end

# not API call, come here via browser only: has cookies and referrer
get '/welcome' do
  redirect to("/account/login?from=_home") unless who = cookies[:who]

  unless login_session_items = JSON.parse(@redis.get(who))
    halt 470, "err: invalid login session items"
  end

  unless @account = Account.find_by(id: login_session_items["id"])
    halt 470, "err: invalid account info in login session"
  end

  @referrer = request.referrer
  erb :welcome
end

get '/' do
  redirect to("/account/login?from=_home")
end

# call from browser
get '/account/login' do
  halt 451, "err: from nowhere" unless client_key = params["from"]
  halt 452, "err: invalid app" unless @client = Client.find_by_appkey(client_key)

  proc_session_key = SecureRandom.uuid
  proc_expire = (Time.now + (5 * 60)).to_i
  @redis.set proc_session_key, { proc_expire: proc_expire }.to_json

  # if already logged on, go client's callback asap
  if (who = cookies[:who]) &&
     (@redis.exists(who)) &&
     (login_session_items = JSON.parse(@redis.get(who))) &&
     (account = Account.find_by(id: login_session_items[:id])) &&
     (account.apps.exists?(@client.id))
    redirect to(@client.callback_url + "?who=#{who}&ticket=#{proc_session_key}")
  end

  @hidden_code = proc_session_key
  erb :login
end

post '/account/login' do
  halt 451, "err: from nowhere" unless client_key = params["from"]
  halt 452, "err: wrong app" unless client = Client.find_by_appkey(client_key)

  # validate form
  halt 453, "err: no form code" unless proc_key = params["code"]
  halt 453, "err: no form code" unless @redis.exists(proc_key)
  halt 453, "err: invalid form code" unless proc_items = JSON.parse(@redis.get(proc_key))
  halt 454, "err: form timeout" unless Time.now.to_i < proc_items["proc_expire"]

  # validate account
  halt 455, "err: no name" unless name = params["name"]
  halt 455, "err: no pass" unless pass = params["pass"]
  halt 456, "err: wrong name" unless account = Account.find_by_name(name)
  halt 459, "err: no access" unless account.apps.exists?(client.id)
  halt 456, "err: wrong password" unless account.password == pass

  # login user: login session key => who => hashed user name
  who = Digest::MD5.hexdigest(account.name)
  # may contain other info as login session content
  @redis.set who, { id: account.id, name: account.name, apps: account.app_ids.join('_') }.to_json

  # reset proc session
  @redis.del proc_key  # del old one
  proc_key = SecureRandom.uuid
  proc_expire = (Time.now + (5 * 60)).to_i
  @redis.set proc_key, { proc_expire: proc_expire }.to_json

  # set persona cookie
  cookies[:who] = who

  # redirect to callback url
  redirect to(client.callback_url + "?who=#{who}&ticket=#{proc_key}")
end

# every time redirect to client's callback_url,
# client will call this api
# this API should be validated
get '/check/:ticket' do |ticket|
  # check API access
  # HEADER NEED
  halt 460, "err: no header: appkey" unless header_appkey = request.env["HTTP_X_APPKEY"]
  halt 460, "err: no header: mac" unless header_mac = request.env["HTTP_X_MAC"]
  halt 460, "err: no header: who" unless header_who = request.env["HTTP_X_WHO"]
  halt 452, "err: invalid appkey" unless client = Client.find_by_appkey(header_appkey)
  halt 461, "err: wrong mac" unless header_mac == client.build_mac(request.path)

  # not from browser, so no cookies and same session...
  # so we still need a redirect
  # Or not rely on session or cookies
  halt 455, "err: not logged in" unless @redis.exists(header_who)
  halt 455, "err: invalid who" unless login_items = JSON.parse(@redis.get(header_who))
  halt 456, "err: wrong who content id" unless account = Account.find_by(id: login_items["id"])
  halt 459, "err: no access" unless account.apps.exists?(client.id)

  # get proc session info
  halt 462, "err: no proc session of such ticket" unless @redis.exists(ticket)
  halt 462, "err: invalid ticket" unless proc_items = JSON.parse(@redis.get(ticket))
  halt 454, "err: ticket timeout" unless Time.now.to_i < proc_items["proc_expire"]

  # all OK, delete proc session in redis
  @redis.del(ticket)
  # return account info as success
  json account: account
end

# logout from SSO, called via browser
# so has cookies
get '/account/logout' do
  halt 465, "err: no who" unless who = cookies[:who]
  halt 466, "err: invalid who" unless @redis.exists(who)

  @redis.del(who)
  redirect to("/")
end

# on for dev purpose
get '/reset' do
  @redis.flushdb
end
