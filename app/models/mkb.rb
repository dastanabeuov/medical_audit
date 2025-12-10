class Mkb < ApplicationRecord
  has_neighbors :embedding

  validates :code, presence: true, uniqueness: true
  validates :title, presence: true

  scope :search_by_text, ->(query) {
    where("code ILIKE :q OR title ILIKE :q OR description ILIKE :q", q: "%#{query}%")
  }

  # Поиск похожих МКБ по векторному сходству
  def self.search_similar(query_embedding, limit: 5)
    nearest_neighbors(:embedding, query_embedding, distance: "cosine").limit(limit)
  end

  def full_text
    "#{code}: #{title}\n#{description}"
  end
end
