# frozen_string_literal: true

module Cabinet
  module Doctors
    class ConfirmationsController < Devise::ConfirmationsController
      layout "doctor"

      protected

      def after_confirmation_path_for(_resource_name, resource)
        cabinet_doctors_dashboard_path
      end
    end
  end
end
