# frozen_string_literal: true

module Cabinet
  module Auditors
    class AdvisorySheetsController < BaseController
      def index
        @tab = params[:tab] || "all"
        @search = params[:search]

        @sheets = fetch_sheets
        @sheets = @sheets.search_text(@search) if @search.present?
        @sheets = @sheets.page(params[:page]).per(20)
      end

      def show
        @sheet = VerifiedAdvisorySheet.find(params[:id])
      end

      def upload
        # Форма загрузки файлов
      end

      def create
        files = params[:files]

        if files.blank?
          redirect_to upload_cabinet_auditors_advisory_sheets_path, alert: "Выберите файлы для загрузки"
          return
        end

        # Обработка файлов
        result = AdvisorySheetUploadService.process_files(files, current_auditor)

        if result[:success] > 0
          # Запускаем проверку загруженных КЛ
          VerifyAllAdvisorySheetsJob.perform_later

          flash[:notice] = "Загружено #{result[:success]} файлов. Проверка запущена в фоновом режиме."
        end

        if result[:failed] > 0
          flash[:alert] = "Не удалось загрузить #{result[:failed]} файлов: #{result[:errors].first(3).join(', ')}"
        end

        redirect_to cabinet_auditors_advisory_sheets_path
      end

      private

      def fetch_sheets
        base = VerifiedAdvisorySheet.where(auditor: current_auditor).order(created_at: :desc)

        case @tab
        when "red"
          base.red
        when "yellow"
          base.yellow
        when "green"
          base.green
        else
          base
        end
      end
    end
  end
end
