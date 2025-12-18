module HomeHelper
  def current_year
    Time.current.year
  end

  def flash_key(key)
    case key.to_sym
    when :notice, :success
      "alert-success"
    when :info
      "alert-info"
    when :warning
      "alert-warning"
    when :error, :alert, :danger
      "alert-danger"
    else
      "alert-primary"
    end
  end
end
