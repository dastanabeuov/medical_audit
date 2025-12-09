# frozen_string_literal: true

# Job для массовой проверки всех непроверенных КЛ
class VerifyAllAdvisorySheetsJob < ApplicationJob
  queue_as :verification

  def perform
    Rails.logger.info("VerifyAllAdvisorySheetsJob: начало массовой проверки")

    pending_sheets = NotVerifiedAdvisorySheet.all
    total = pending_sheets.count

    Rails.logger.info("VerifyAllAdvisorySheetsJob: найдено #{total} КЛ для проверки")

    # Запускаем отдельные jobs для каждого КЛ (параллельная обработка)
    pending_sheets.find_each do |sheet|
      VerifyAdvisorySheetJob.perform_later(sheet.id)
    end

    Rails.logger.info("VerifyAllAdvisorySheetsJob: запущено #{total} задач проверки")
  end
end
