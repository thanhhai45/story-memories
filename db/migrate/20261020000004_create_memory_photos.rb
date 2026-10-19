class CreateMemoryPhotos < ActiveRecord::Migration[8.0]
  def change
    create_table :memory_photos do |t|
      t.references :memory, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.integer :position, null: false, default: 0
      t.string :caption
      t.date :taken_at
      t.string :alt_text
      t.boolean :cover, null: false, default: false

      t.timestamps
    end
    add_index :memory_photos, [ :memory_id, :position ]
  end
end
