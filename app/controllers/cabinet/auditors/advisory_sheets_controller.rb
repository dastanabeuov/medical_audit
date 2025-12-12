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

        # Временная отладка - удалите после исправления
        # Rails.logger.info "=" * 50
        # Rails.logger.info "FILES RAW: #{files.inspect}"
        # Rails.logger.info "FILES CLASS: #{files.class}"
        # if files.present?
        #   files.each_with_index do |f, i|
        #     Rails.logger.info "FILE[#{i}] CLASS: #{f.class}, VALUE: #{f.inspect[0..100]}"
        #   end
        # end
        # Rails.logger.info "=" * 50
        ###############################################

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
