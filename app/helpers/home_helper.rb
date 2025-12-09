module HomeHelper
  def current_year
    Time.current.year
  end

  def full_name(user)
    "#{user.first_name} #{user.last_name}"
  end
end
