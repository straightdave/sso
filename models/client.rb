require 'digest'

class Client
  attr_accessor :id, :name, :appkey, :skey, :callback_url

  def initialize(id, name, appkey, skey, callback_url)
    @id, @name, @appkey, @skey, @callback_url = id, name, appkey, skey, callback_url
  end

  def build_mac(content)
    Digest::MD5.hexdigest("#{content}_#{self.skey}")
  end

  def self.find_by_id(id)
    Client.new(id, "client_#{id}", "appkey_#{id}", "skey_#{id}", "")
  end

  def self.find_by_appkey(appkey)
    if appkey == '_home'
      Client.new(0, "sso_home", "appkey_sso", "skey_sso")
    else
      id = appkey.split('_')[1]
      Client.new(id, "client_#{id}", "appkey_#{id}", "skey_#{id}")
    end
  end

  def self.all(num = 4)
    ret = []
    (1 .. num).each do |id|
      ret << Client.new(id, "client_#{id}", "appkey_#{id}", "skey_#{id}")
    end
    ret
  end
end
