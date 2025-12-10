# frozen_string_literal: true

# Job для проверки одного консультативного листа
class VerifyAdvisorySheetJob < ApplicationJob
  queue_as :verification

  def perform(not_verified_sheet_id)
    sheet = NotVerifiedAdvisorySheet.find_by(id: not_verified_sheet_id)
    return unless sheet

    Rails.logger.info("VerifyAdvisorySheetJob: проверка КЛ ##{sheet.recording}")

    # Проверяем КЛ
    result = AdvisorySheetVerificationService.verify(sheet)

    if result
      # Удаляем из not_verified после успешной проверки
      sheet.destroy
      Rails.logger.info("VerifyAdvisorySheetJob: КЛ ##{sheet.recording} проверен, статус: #{result.status}")
    else
      Rails.logger.error("VerifyAdvisorySheetJob: ошибка проверки КЛ ##{sheet.recording}")
    end
  end
end
