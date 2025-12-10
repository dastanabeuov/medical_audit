# frozen_string_literal: true

module Cabinet
  module MainDoctors
    class DashboardController < BaseController
      def index
        @doctors = current_main_doctor.doctors
        # Будущий функционал для уведомлений
      end
    end
  end
end
