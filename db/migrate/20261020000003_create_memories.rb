class CreateMemories < ActiveRecord::Migration[8.0]
  def change
    create_table :memories do |t|
      t.string :title, null: false
      t.string :occasion, null: false, default: "anniversary"
      t.date :start_date
      t.date :end_date
      t.string :person_names
      t.text :story_notes
      t.string :style, null: false, default: "romantic"
      t.string :status, null: false, default: "draft"
      t.string :share_token
      t.boolean :share_enabled, null: false, default: false
      t.references :video_template, foreign_key: { on_delete: :nullify }
      t.string :music_track

      t.timestamps
    end
    add_index :memories, :share_token, unique: true
    add_index :memories, :updated_at
  end
end
