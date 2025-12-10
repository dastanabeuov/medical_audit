# frozen_string_literal: true

module Cabinet
  module MainDoctors
    class SessionsController < Devise::SessionsController
      layout "cabinet"

      protected

      def after_sign_in_path_for(_resource)
        cabinet_main_doctors_dashboard_path
      end

      def after_sign_out_path_for(_resource_or_scope)
        root_path
      end
    end
  end
end
