class CreateAuditBatches < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_batches do |t|
      t.string :name
      t.integer :status
      t.integer :total_sheets
      t.integer :processed_sheets

      t.timestamps
    end
  end
end
