class BatchProcessorJob < ApplicationJob
  queue_as :default

  def perform(batch_id)
    batch = AuditBatch.find(batch_id)

    batch.process!
  end
end
