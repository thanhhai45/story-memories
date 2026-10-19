class CreateVideoRenders < ActiveRecord::Migration[8.0]
  def change
    create_table :video_renders do |t|
      t.references :memory, null: false, foreign_key: { on_delete: :cascade }
      t.references :story, foreign_key: { on_delete: :nullify }
      t.references :video_template, foreign_key: { on_delete: :nullify }
      t.string :status, null: false, default: "queued"
      t.integer :progress, null: false, default: 0
      t.string :music_track
      t.jsonb :metadata, null: false, default: {}
      t.text :error_message
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end
    add_check_constraint :video_renders, "progress BETWEEN 0 AND 100", name: "video_renders_progress_range"
  end
end
