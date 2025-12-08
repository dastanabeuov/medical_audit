class AuditBatchesController < ApplicationController
  def index
    @batches = AuditBatch.order(created_at: :desc).page(params[:page])
  end

  def show
    @batch = AuditBatch.find(params[:id])
    @sheets = @batch.consultation_sheets
      .includes(:audits)
      .order(risk_level: :desc, score: :asc)
  end

  def summary
    @batch = AuditBatch.find(params[:id])

    render json: {
      id: @batch.id,
      name: @batch.name,
      status: @batch.status,
      progress: @batch.completion_percentage,
      total: @batch.total_sheets,
      processed: @batch.processed_sheets,
      risk_summary: @batch.risk_summary
    }
  end
end
