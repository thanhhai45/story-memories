require "test_helper"

class MemoryTest < ActiveSupport::TestCase
  test "requires a title" do
    memory = Memory.new(title: "  ")
    assert_not memory.valid?
    assert memory.errors.added?(:title, :blank)
  end

  test "applies defaults on create" do
    memory = Memory.create!(title: "Ngày yêu nhau", style: "playful")
    assert_equal "anniversary", memory.occasion
    assert_equal "draft", memory.status
    assert_equal "vui_tuoi", memory.music_track
    assert_not memory.share_enabled?
    assert_nil memory.share_token
    assert_not_nil memory.video_template
  end

  test "rejects end date before start date" do
    memory = Memory.new(title: "x", start_date: Date.new(2024, 5, 1), end_date: Date.new(2023, 5, 1))
    assert_not memory.valid?
    assert memory.errors.key?(:end_date)
  end

  test "rejects unknown occasion, style and music" do
    memory = Memory.new(title: "x", occasion: "hack", style: "weird", music_track: "../../etc/passwd")
    assert_not memory.valid?
    assert memory.errors.key?(:occasion)
    assert memory.errors.key?(:style)
    assert memory.errors.key?(:music_track)
  end

  test "share tokens are long, random and unique" do
    memory = memories(:wedding)
    memory.enable_sharing!
    first = memory.share_token
    assert_operator first.length, :>=, 32
    assert_match(/\A[A-Za-z0-9_\-]+\z/, first)

    memory.regenerate_share_token!
    assert_not_equal first, memory.share_token
    assert_nil Memory.find_shared(first)
    assert_equal memory, Memory.find_shared(memory.share_token)
  end

  test "find_shared requires sharing to be enabled" do
    memory = memories(:birthday)
    assert_equal memory, Memory.find_shared(memory.share_token)

    memory.disable_sharing!
    assert_nil Memory.find_shared(memory.share_token)
    assert_nil Memory.find_shared("")
    assert_nil Memory.find_shared(nil)
  end

  test "period label uses years" do
    assert_equal "2020 — 2026", memories(:wedding).period_label
    assert_nil memories(:birthday).period_label
  end

  test "ready for render needs photos and a completed story" do
    memory = memories(:wedding)
    assert_not memory.ready_for_render?
    attach_photo(memory)
    assert memory.reload.ready_for_render?
  end
end
