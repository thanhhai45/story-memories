require "test_helper"

class Videos::RendererTest < ActiveSupport::TestCase
  setup { skip "FFmpeg chưa được cài" unless ffmpeg_available? }

  def render_with(layout)
    photos = [ { id: 1, caption: "Đà Lạt 100% 'mùa thu' : [x]" }, { id: 2, caption: nil } ]
    config = { "layout" => layout, "width" => 320, "height" => 180, "fps" => 12, "transition" => 0.3,
               "title_duration" => 1, "chapter_duration" => 1, "photo_duration" => 1, "ending_duration" => 1 }
    timeline = Videos::TimelineBuilder.new(
      content: { "title" => "6 năm cùng nhau", "subtitle" => "2020 — 2026", "ending" => "Mãi bên nhau",
                 "scenes" => [ { "title" => "Bắt đầu", "narration" => "Một hành trình mới", "photo_positions" => [ 1, 2 ] } ] },
      photos:, config:
    ).call

    Dir.mktmpdir do |dir|
      progress = []
      output, info = Videos::Renderer.new(
        timeline:, config:, work_dir: dir,
        photo_paths: { 1 => file_fixture("photo.jpg").to_s, 2 => file_fixture("portrait.png").to_s },
        fonts_dir: Rails.root.join("app/assets/fonts"),
        music_path: MusicLibrary.path_for("piano_nhe_nhang"),
        on_progress: ->(p) { progress << p }
      ).call

      assert File.exist?(output)
      assert_equal 320, info.width
      assert_equal 180, info.height
      assert_equal "h264", info.video_codec
      assert_equal "aac", info.audio_codec
      assert_in_delta timeline.total_duration, info.duration, 0.5
      assert_equal 100, progress.last
    end
  end

  test "renders the cinematic template" do
    render_with("cinematic")
  end

  test "renders the album template" do
    render_with("album")
  end

  test "fails cleanly when a photo is missing" do
    timeline = Videos::TimelineBuilder.new(content: { "title" => "T" }, photos: [ { id: 9 } ], config: {}).call
    error = assert_raises(Videos::Error) do
      Videos::Renderer.new(timeline:, photo_paths: {}, config: {}, work_dir: Dir.mktmpdir,
                           fonts_dir: Rails.root.join("app/assets/fonts")).call
    end
    assert_match "ảnh", error.user_message
  end
end
