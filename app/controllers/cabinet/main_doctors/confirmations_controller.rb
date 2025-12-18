# frozen_string_literal: true

module Cabinet
  module MainDoctors
    class ConfirmationsController < Devise::ConfirmationsController
      layout "main_doctor"

      protected

      def after_confirmation_path_for(_resource_name, resource)
        cabinet_main_doctors_dashboard_path
      end
    end
  end
end
