class KnowledgeDocument < ApplicationRecord
  has_neighbors :embedding, dimensions: 3072

  belongs_to :parent_document, class_name: "KnowledgeDocument",
             optional: true
  has_many :child_chunks, class_name: "KnowledgeDocument",
           foreign_key: :parent_document_id

  enum document_type: {
    mkb: 0,           # МКБ-10/11
    protocol: 1,       # Протоколы МЗ РК
    guideline: 2       # Клинические рекомендации
  }

  validates :title, :content, presence: true

  # Генерация embeddings перед сохранением
  before_save :generate_embedding, if: :content_changed?

  # Поиск релевантных документов
  def self.search(query, limit: 5)
    embedding = generate_query_embedding(query)
    nearest_neighbors(:embedding, embedding, distance: "cosine").limit(limit)
  end

  # Chunking для больших документов (>8000 tokens)
  def self.create_with_chunking(title:, content:, document_type:,
                                  source:, metadata: {})
    parent = create!(
      title: title,
      content: content[0..1000], # Краткое содержание
      document_type: document_type,
      source: source,
      metadata: metadata
    )

    chunks = chunk_text(content, max_tokens: 8000)

    chunks.each_with_index do |chunk, index|
      create!(
        title: "#{title} (часть #{index + 1})",
        content: chunk,
        document_type: document_type,
        source: source,
        metadata: metadata,
        parent_document_id: parent.id,
        chunk_index: index
      )
    end

    parent
  end

  private

  def generate_embedding
    return if content.blank?

    response = RubyLLM.embed(content, model: "text-embedding-3-large")
    self.embedding = response.vectors
  rescue => e
    Rails.logger.error("Embedding generation failed: #{e.message}")
    raise
  end

  def self.generate_query_embedding(query)
    response = RubyLLM.embed(query, model: "text-embedding-3-large")
    response.vectors
  end

  def self.chunk_text(text, max_tokens: 8000)
    encoder = Tiktoken.encoding_for_model("gpt-4")
    tokens = encoder.encode(text)

    chunks = []
    current_chunk = []

    tokens.each_slice(max_tokens) do |token_chunk|
      chunks << encoder.decode(token_chunk)
    end

    chunks
  end
end
