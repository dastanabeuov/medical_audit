# frozen_string_literal: true

module Cabinet
  module Auditors
    # Контроллер для управления списком врачей в кабинете аудитора
    class DoctorsController < BaseController
      # GET /cabinet/auditors/doctors
      def index
        @doctors = Doctor.order(created_at: :desc)
                         .includes(:verified_advisory_sheets)

        # Добавляем информацию о пароле (по умолчанию Qq123456! для всех)
        @default_password = "Qq123456!"
      end
    end
  end
end
