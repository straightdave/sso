class Account
  attr_accessor :id, :name, :password, :apps



  def self.all
    ret = []
    ret << Account.new(1, "user_#{id}", "123123", [1, 2])
    ret << Account.new(2, "user_#{id}", "123123", [1, 2, 3])
    ret << Account.new(3, "user_#{id}", "123123", [1, 2, 3, 4])
    ret
  end

  def self.find_by_id(id)
    Account.new(id, "user_#{id}", "123123", [1, 2, 3, 4])
  end

end
