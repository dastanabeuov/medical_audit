# frozen_string_literal: true

require "csv"

module Cabinet
  module Auditors
    # Контроллер для экспорта отчетов по консультативным листам
    # Отвечает ТОЛЬКО за HTTP логику и формирование ответа
    class ReportsController < Cabinet::Auditors::BaseController
      # GET /cabinet/auditors/reports/export.csv
      def export
        @sheets = filtered_sheets

        respond_to do |format|
          format.csv { send_csv_report }
          format.html { redirect_to cabinet_auditors_advisory_sheets_path, alert: "Неподдерживаемый формат" }
        end
      end

      # GET /cabinet/auditors/reports/summary
      def summary
        @sheets = filtered_sheets
        @summary = AdvisorySheetReportService.generate_summary(@sheets)
      end

      private

      # Получает отфильтрованную коллекцию листов
      def filtered_sheets
        sheets = VerifiedAdvisorySheet.all

        # Фильтр по статусу
        sheets = sheets.by_status(params[:status]) if params[:status].present?

        # Фильтр по дате
        if params[:from_date].present?
          sheets = sheets.where("verified_at >= ?", Date.parse(params[:from_date]))
        end

        if params[:to_date].present?
          sheets = sheets.where("verified_at <= ?", Date.parse(params[:to_date]).end_of_day)
        end

        # Фильтр по качеству
        if params[:min_percentage].present?
          sheets = sheets.joins(:advisory_sheet_score)
                        .where("advisory_sheet_scores.percentage >= ?", params[:min_percentage])
        end

        sheets
      end

      # Генерирует и отправляет CSV файл
      def send_csv_report
        # Генерируем данные через сервис
        report_data = AdvisorySheetReportService.generate_report_data(@sheets)

        # Формируем CSV
        csv_content = generate_csv(report_data)

        # Отправляем файл
        send_data csv_content,
                  filename: csv_filename,
                  type: "text/csv; charset=utf-8",
                  disposition: "attachment"
      end

      # Генерирует CSV контент
      def generate_csv(report_data)
        CSV.generate(headers: true, col_sep: ";", encoding: "UTF-8") do |csv|
          # BOM для корректного открытия в Excel
          csv << [ "\uFEFF" + AdvisorySheetReportService.report_headers.first ] +
                 AdvisorySheetReportService.report_headers[1..]

          # Данные
          report_data.each do |row|
            csv << AdvisorySheetReportService.row_to_array(row)
          end
        end
      end

      # Генерирует имя файла с датой
      def csv_filename
        timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
        "advisory_sheets_report_#{timestamp}.csv"
      end
    end
  end
end
