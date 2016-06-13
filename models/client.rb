require 'digest'

class Client < ActiveRecord::Base

  def build_mac(content)
    Digest::MD5.hexdigest("#{content}_#{self.skey}")
  end

  def self.find_by_appkey(appkey)
    Client.find_by(appkey: appkey)
  end

end
