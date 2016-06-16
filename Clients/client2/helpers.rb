helpers do
  def login?
    !session[:user_id].nil? && !session[:user_name].nil?
  end
end
