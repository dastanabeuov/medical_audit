# frozen_string_literal: true

# Job для проверки одного консультативного листа
class VerifyAdvisorySheetJob < ApplicationJob
  queue_as :verification

  def perform(not_verified_sheet_id)
    sheet = NotVerifiedAdvisorySheet.find_by(id: not_verified_sheet_id)
    return unless sheet

    Rails.logger.info("VerifyAdvisorySheetJob: проверка КЛ ##{sheet.recording}")

    begin
      # Проверяем КЛ
      result = AdvisorySheetVerificationService.verify(sheet)

      if result && result.persisted?
        # Удаляем из not_verified только после успешного создания verified
        sheet.destroy
        Rails.logger.info("VerifyAdvisorySheetJob: КЛ ##{sheet.recording} проверен, статус: #{result.status}")
      else
        Rails.logger.error("VerifyAdvisorySheetJob: не удалось создать verified sheet для КЛ ##{sheet.recording}")
      end
    rescue StandardError => e
      Rails.logger.error("VerifyAdvisorySheetJob: исключение при проверке КЛ ##{sheet.recording}: #{e.class} - #{e.message}")
      Rails.logger.error(e.backtrace.first(5).join("\n"))
      # НЕ удаляем sheet при ошибке - оставляем для повторной попытки или ручной обработки
    end
  end
end
