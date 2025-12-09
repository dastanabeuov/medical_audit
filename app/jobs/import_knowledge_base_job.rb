# frozen_string_literal: true

# Job для импорта/обновления базы знаний (протоколы и МКБ)
class ImportKnowledgeBaseJob < ApplicationJob
  queue_as :import

  def perform(refresh: false)
    Rails.logger.info("ImportKnowledgeBaseJob: #{refresh ? 'обновление' : 'импорт'} базы знаний")

    # Импорт протоколов
    protocol_result = if refresh
                        ProtocolImportService.refresh_all
    else
                        ProtocolImportService.import_all
    end

    Rails.logger.info("Протоколы: #{protocol_result}")

    # Импорт МКБ
    mkb_result = if refresh
                   MkbImportService.refresh_all
    else
                   MkbImportService.import_all
    end

    Rails.logger.info("МКБ: #{mkb_result}")

    {
      protocols: protocol_result,
      mkb: mkb_result
    }
  end
end
