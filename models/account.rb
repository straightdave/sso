class Account < ActiveRecord::Base
  has_and_belongs_to_many :apps, class_name: "Client"
end
