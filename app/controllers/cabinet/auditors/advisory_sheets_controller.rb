# frozen_string_literal: true

module Cabinet
  module Auditors
    class AdvisorySheetsController < BaseController
      before_action :set_sheet, only: [ :show, :destroy ]
      def index
        @tab = params[:tab] || "all"
        @search = params[:search]

        # Сначала применяем поиск, затем фильтрацию
        if @search.present?
          @sheets = VerifiedAdvisorySheet.search_text(@search)
          # Применяем фильтр по статусу после поиска
          @sheets = filter_by_tab(@sheets, @tab)
          @sheets = @sheets.where(auditor: current_auditor)
        else
          @sheets = fetch_sheets
        end

        @sheets = @sheets.page(params[:page]).per(20)
      end

      def show
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

        # Фильтруем только реальные файлы
        uploaded_files = files.reject { |f| f.is_a?(String) || f.blank? }

        if uploaded_files.empty?
          redirect_to upload_cabinet_auditors_advisory_sheets_path, alert: "Не найдено корректных файлов"
          return
        end

        # Обработка файлов
        result = AdvisorySheetUploadService.process_files(uploaded_files, current_auditor)

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

      def destroy
        if @sheet.destroy
          redirect_to cabinet_auditors_advisory_sheets_path, notice: I18n.t(".destroyed")
        else
          redirect_to cabinet_auditors_advisory_sheets_path, alert: I18n.t(".not_destroyed")
        end
      end

      private

      def set_sheet
        @sheet = VerifiedAdvisorySheet.includes(:advisory_sheet_field, :advisory_sheet_score).find(params[:id])
      end

      def fetch_sheets
        base = VerifiedAdvisorySheet.where(auditor: current_auditor).order(created_at: :desc)
        filter_by_tab(base, @tab)
      end

      def filter_by_tab(relation, tab)
        case tab
        when "purple"
          relation.purple
        when "red"
          relation.red
        when "yellow"
          relation.yellow
        when "green"
          relation.green
        else
          relation
        end
      end
    end
  end
end
