require "test_helper"

class StoryTest < ActiveSupport::TestCase
  test "exposes structured content" do
    story = stories(:wedding_story)
    assert_equal "6 năm cùng nhau", story.title
    assert_equal 2, story.scenes.size
    assert story.completed?
  end

  test "completed story must have a title" do
    story = Story.new(memory: memories(:wedding), status: "completed", generated_content: { "title" => "", "scenes" => [] })
    assert_not story.valid?
  end

  test "rejects unknown status" do
    story = Story.new(memory: memories(:wedding), status: "done")
    assert_not story.valid?
  end

  test "apply_edits normalizes user input" do
    story = memories(:birthday).stories.new
    saved = story.apply_edits({
      "title" => "  Mẹ  ", "subtitle" => "", "ending" => "Yêu mẹ",
      "scenes" => [
        { "title" => "Ngày xưa", "narration" => "Ký ức", "photo_positions" => "1, 2, 9, x" },
        { "title" => "", "narration" => "", "photo_positions" => "" }
      ]
    }, photo_count: 3)

    assert saved, story.errors.full_messages.to_sentence
    assert_equal "Mẹ", story.title
    assert_equal 1, story.scenes.size
    assert_equal [ 1, 2 ], story.scenes.first["photo_positions"]
    assert_equal "manual", story.source
    assert story.completed?
  end
end
