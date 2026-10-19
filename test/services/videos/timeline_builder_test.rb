require "test_helper"

class Videos::TimelineBuilderTest < ActiveSupport::TestCase
  PHOTOS = (1..5).map { |i| { id: 100 + i, caption: "Ảnh #{i}" } }

  def build(content, config = {})
    Videos::TimelineBuilder.new(content:, photos: PHOTOS, config: { "photo_duration" => 3 }.merge(config), memory_title: "Kỷ niệm").call
  end

  test "builds title, chapters, photos and ending in order" do
    timeline = build({
      "title" => "T", "subtitle" => "S", "ending" => "E",
      "scenes" => [
        { "title" => "A", "narration" => "a", "photo_positions" => [ 1, 2 ] },
        { "title" => "B", "narration" => "b", "photo_positions" => [ 3 ] }
      ]
    })
    kinds = timeline.segments.map { |s| s[:kind] }
    assert_equal %w[title chapter photo photo chapter photo photo photo ending], kinds
    # ảnh 4, 5 không được gán -> nối vào chương cuối, đúng thứ tự
    assert_equal [ 101, 102, 103, 104, 105 ], timeline.photo_segments.map { |s| s[:photo_id] }
  end

  test "ignores invalid and duplicate positions" do
    timeline = build({ "title" => "T", "scenes" => [
      { "title" => "A", "photo_positions" => [ 2, 2, 99, -1, "x" ] },
      { "title" => "B", "photo_positions" => [ 2, 1 ] }
    ] })
    assert_equal [ 102, 101, 103, 104, 105 ], timeline.photo_segments.map { |s| s[:photo_id] }
  end

  test "works without scenes or ending" do
    timeline = build({ "title" => "" })
    assert_equal "Kỷ niệm", timeline.segments.first[:title]
    assert_equal 5, timeline.photo_segments.size
    assert_not timeline.segments.any? { |s| s[:kind] == "ending" }
  end

  test "shrinks photo duration to respect max duration" do
    timeline = build({ "title" => "T" }, "photo_duration" => 10, "max_duration" => 30)
    assert_operator timeline.total_duration, :<=, 30.5
    assert timeline.photo_segments.all? { |s| s[:duration] >= Videos::TimelineBuilder::MIN_PHOTO_DURATION }
  end

  test "requires photos" do
    assert_raises(Videos::Error) do
      Videos::TimelineBuilder.new(content: {}, photos: [], config: {}).call
    end
  end
end
