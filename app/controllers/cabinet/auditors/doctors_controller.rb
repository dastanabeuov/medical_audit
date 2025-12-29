# frozen_string_literal: true

module Cabinet
  module Auditors
    # Контроллер для управления списком врачей в кабинете аудитора
    class DoctorsController < BaseController
      # GET /cabinet/auditors/doctors
      def index
        @doctors = Doctor.all

        # Поиск по всем полям, включая полное ФИО
        if params[:search].present?
          search_term = "%#{params[:search]}%"
          @doctors = @doctors.where(
            "(last_name || ' ' || first_name || ' ' || COALESCE(second_name, '')) ILIKE ? OR
             first_name ILIKE ? OR last_name ILIKE ? OR second_name ILIKE ? OR
             email ILIKE ? OR department ILIKE ? OR specialization ILIKE ? OR clinic ILIKE ?",
            search_term, search_term, search_term, search_term, search_term, search_term, search_term, search_term
          )
        end

        @doctors = @doctors.left_joins(:verified_advisory_sheets)
                          .select("doctors.*, COUNT(verified_advisory_sheets.id) as sheets_count")
                          .group("doctors.id")
                          .order("sheets_count DESC, doctors.created_at DESC")
                          .page(params[:page])
                          .per(10)

        # Добавляем информацию о пароле (по умолчанию Qq123456! для всех)
        @default_password = "Qq123456!"
      end
    end
  end
end
