class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  protected

  def after_sign_in_path_for(resource)
    case resource
    when Auditor
      cabinet_auditors_dashboard_path
    when MainDoctor
      cabinet_main_doctors_dashboard_path
    when Doctor
      cabinet_doctors_dashboard_path
    else
      root_path
    end
  end

  def after_sign_out_path_for(_resource_or_scope)
    root_path
  end
end
