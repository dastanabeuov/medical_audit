class AddEmbeddingsToKnowledgeDocuments < ActiveRecord::Migration[8.0]
  def change
    add_column :knowledge_documents, :embedding, :vector, limit: 3072
    add_index :knowledge_documents, :embedding, using: :hnsw,
              opclass: :vector_cosine_ops

    add_column :knowledge_documents, :chunk_index, :integer
    add_column :knowledge_documents, :parent_document_id, :bigint
    add_index :knowledge_documents, :parent_document_id
  end
end
