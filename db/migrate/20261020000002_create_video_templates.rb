class CreateVideoTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :video_templates do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.jsonb :configuration, null: false, default: {}
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :video_templates, :slug, unique: true
  end
end
