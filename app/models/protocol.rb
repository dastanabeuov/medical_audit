class Protocol < ApplicationRecord
  has_neighbors :embedding

  validates :title, presence: true
  validates :content, presence: true

  scope :search_by_text, ->(query) {
    where("title ILIKE :q OR content ILIKE :q", q: "%#{query}%")
  }

  # Поиск похожих протоколов по векторному сходству
  def self.search_similar(query_embedding, limit: 5)
    nearest_neighbors(:embedding, query_embedding, distance: "cosine").limit(limit)
  end

  def full_text
    "#{title}\n#{content}"
  end
end
