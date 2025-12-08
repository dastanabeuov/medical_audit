class ConsultationSheetAnalysisJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(consultation_sheet_id)
    sheet = ConsultationSheet.find(consultation_sheet_id)

    sheet.analyze!

    # Обновляем прогресс батча
    sheet.audit_batch&.update_progress!

    # Отправляем уведомление через ActionCable
    broadcast_completion(sheet)
  rescue => e
    Rails.logger.error("Analysis failed for sheet #{consultation_sheet_id}: #{e.message}")
    sheet.update!(status: :failed, findings: { error: e.message })
    raise
  end

  private

  def broadcast_completion(sheet)
    ActionCable.server.broadcast(
      "audit_batch_#{sheet.audit_batch_id}",
      {
        type: "sheet_completed",
        sheet_id: sheet.id,
        risk_level: sheet.risk_level,
        score: sheet.score
      }
    )
  end
end
