helpers do
  def login?
    !session[:account_id].nil? && !session[:account_name].nil?
  end

  def logout
    session.destroy
  end
end
