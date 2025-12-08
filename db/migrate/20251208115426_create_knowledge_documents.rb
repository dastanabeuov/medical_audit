class CreateKnowledgeDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :knowledge_documents, if_not_exists: true do |t|
      t.string :title
      t.text :content
      t.string :document_type
      t.string :source
      t.jsonb :metadata

      t.timestamps
    end
  end
end
