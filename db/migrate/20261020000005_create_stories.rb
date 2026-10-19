class CreateStories < ActiveRecord::Migration[8.0]
  def change
    create_table :stories do |t|
      t.references :memory, null: false, foreign_key: { on_delete: :cascade }
      t.string :status, null: false, default: "pending"
      t.jsonb :prompt_data, null: false, default: {}
      t.jsonb :generated_content, null: false, default: {}
      t.text :error_message
      t.datetime :generated_at

      t.timestamps
    end
  end
end
