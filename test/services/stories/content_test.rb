require "test_helper"

class Stories::ContentTest < ActiveSupport::TestCase
  test "normalizes and clamps AI output" do
    raw = {
      title: "  6 năm   cùng nhau ", subtitle: 2026,
      scenes: [
        { title: "A", narration: "x" * 999, photo_positions: [ 1, "2", 2, 0, 99, "abc" ] },
        "not a hash",
        { title: "", narration: "", photo_positions: [] }
      ],
      ending: "Kết"
    }
    content = Stories::Content.normalize(raw, photo_count: 3)

    assert_equal "6 năm cùng nhau", content["title"]
    assert_equal "2026", content["subtitle"]
    assert_equal 1, content["scenes"].size
    assert_equal [ 1, 2 ], content["scenes"][0]["photo_positions"]
    assert_operator content["scenes"][0]["narration"].length, :<=, Stories::Content::LIMITS[:narration]
    assert_empty Stories::Content.errors_for(content)
  end

  test "accepts indexed hash scenes from forms" do
    content = Stories::Content.normalize({ "title" => "T", "scenes" => { "0" => { "title" => "S", "photo_positions" => "1 3" } } }, photo_count: 3)
    assert_equal [ 1, 3 ], content["scenes"][0]["photo_positions"]
  end

  test "reports missing title" do
    assert_includes Stories::Content.errors_for({ "title" => "", "scenes" => [] }).join, "Tiêu đề"
  end
end
