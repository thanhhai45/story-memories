# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_10_20_000006) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "memories", force: :cascade do |t|
    t.string "title", null: false
    t.string "occasion", default: "anniversary", null: false
    t.date "start_date"
    t.date "end_date"
    t.string "person_names"
    t.text "story_notes"
    t.string "style", default: "romantic", null: false
    t.string "status", default: "draft", null: false
    t.string "share_token"
    t.boolean "share_enabled", default: false, null: false
    t.bigint "video_template_id"
    t.string "music_track"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["share_token"], name: "index_memories_on_share_token", unique: true
    t.index ["updated_at"], name: "index_memories_on_updated_at"
    t.index ["video_template_id"], name: "index_memories_on_video_template_id"
  end

  create_table "memory_photos", force: :cascade do |t|
    t.bigint "memory_id", null: false
    t.integer "position", default: 0, null: false
    t.string "caption"
    t.date "taken_at"
    t.string "alt_text"
    t.boolean "cover", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["memory_id", "position"], name: "index_memory_photos_on_memory_id_and_position"
  end

  create_table "stories", force: :cascade do |t|
    t.bigint "memory_id", null: false
    t.string "status", default: "pending", null: false
    t.jsonb "prompt_data", default: {}, null: false
    t.jsonb "generated_content", default: {}, null: false
    t.text "error_message"
    t.datetime "generated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["memory_id"], name: "index_stories_on_memory_id"
  end

  create_table "video_renders", force: :cascade do |t|
    t.bigint "memory_id", null: false
    t.bigint "story_id"
    t.bigint "video_template_id"
    t.string "status", default: "queued", null: false
    t.integer "progress", default: 0, null: false
    t.string "music_track"
    t.jsonb "metadata", default: {}, null: false
    t.text "error_message"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["memory_id"], name: "index_video_renders_on_memory_id"
    t.index ["story_id"], name: "index_video_renders_on_story_id"
    t.index ["video_template_id"], name: "index_video_renders_on_video_template_id"
    t.check_constraint "progress >= 0 AND progress <= 100", name: "video_renders_progress_range"
  end

  create_table "video_templates", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.text "description"
    t.jsonb "configuration", default: {}, null: false
    t.boolean "active", default: true, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_video_templates_on_slug", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "memories", "video_templates", on_delete: :nullify
  add_foreign_key "memory_photos", "memories", on_delete: :cascade
  add_foreign_key "stories", "memories", on_delete: :cascade
  add_foreign_key "video_renders", "memories", on_delete: :cascade
  add_foreign_key "video_renders", "stories", on_delete: :nullify
  add_foreign_key "video_renders", "video_templates", on_delete: :nullify
end
