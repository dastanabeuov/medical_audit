class CreateProtocols < ActiveRecord::Migration[8.0]
  def change
    create_table :protocols do |t|
      t.string :title, null: false
      t.string :code
      t.text :content, null: false
      t.string :source_file
      t.vector :embedding, limit: 768  # Gemini embedding dimension

      t.timestamps
    end

    add_index :protocols, :code
    add_index :protocols, :title
  end
end
