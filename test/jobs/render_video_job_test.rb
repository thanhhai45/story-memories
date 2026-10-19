require "test_helper"

# Kiểm thử end-to-end thật: ảnh -> variant (libvips) -> FFmpeg -> MP4 -> Active Storage.
class RenderVideoJobTest < ActiveJob::TestCase
  setup do
    skip "FFmpeg chưa được cài" unless ffmpeg_available?
    @memory = memories(:wedding)
    attach_photo(@memory, caption: "Đà Lạt")
    attach_photo(@memory, "portrait.png", "image/png")
  end

  test "renders an MP4, stores metadata and marks the memory ready" do
    video_render = @memory.video_renders.create!(story: stories(:wedding_story), video_template: video_templates(:cinematic),
                                                 music_track: "piano_nhe_nhang", status: "queued")
    RenderVideoJob.perform_now(video_render.id)

    video_render.reload
    assert video_render.completed?, video_render.error_message
    assert_equal 100, video_render.progress
    assert video_render.output_video.attached?
    assert_equal "video/mp4", video_render.output_video.content_type
    assert_operator video_render.metadata["duration"], :>, 1
    assert_equal 320, video_render.metadata["width"]
    assert_equal "ready", @memory.reload.status
    assert_empty Dir.glob(Rails.root.join("tmp/renders/render-#{video_render.id}-*"))
  end

  test "album template renders too" do
    video_render = @memory.video_renders.create!(story: stories(:wedding_story), video_template: video_templates(:album),
                                                 music_track: "am_ap", status: "queued")
    RenderVideoJob.perform_now(video_render.id)
    assert video_render.reload.completed?, video_render.error_message
  end

  test "fails gracefully without a story, keeping the memory intact" do
    @memory.stories.destroy_all
    video_render = @memory.video_renders.create!(status: "queued", music_track: "piano_nhe_nhang")
    RenderVideoJob.perform_now(video_render.id)

    video_render.reload
    assert video_render.failed?
    assert_match "lời dẫn", video_render.error_message
    assert_equal 2, @memory.memory_photos.count
    assert_equal "draft", @memory.reload.status
  end

  test "does nothing for renders that are not queued" do
    video_render = @memory.video_renders.create!(status: "completed")
    RenderVideoJob.perform_now(video_render.id)
    assert video_render.reload.completed?
  end
end
