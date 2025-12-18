# frozen_string_literal: true

module Cabinet
  module MainDoctors
    class UnlocksController < Devise::UnlocksController
      layout "main_doctor"

      protected

      def after_unlock_path_for(resource)
        cabinet_main_doctors_dashboard_path
      end
    end
  end
end
