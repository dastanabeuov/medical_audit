class CreateMkbs < ActiveRecord::Migration[8.0]
  def change
    create_table :mkbs do |t|
      t.string :code, null: false
      t.string :title, null: false
      t.text :description
      t.string :source_file
      t.vector :embedding, limit: 768

      t.timestamps
    end

    add_index :mkbs, :code, unique: true
    add_index :mkbs, :title
  end
end
