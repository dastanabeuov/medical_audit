# frozen_string_literal: true

module Cabinet
  module Doctors
    class UnlocksController < Devise::UnlocksController
      layout "doctor"

      protected

      def after_unlock_path_for(resource)
        cabinet_doctors_dashboard_path
      end
    end
  end
end
