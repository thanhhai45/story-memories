require "test_helper"

class VideoRenderTest < ActiveSupport::TestCase
  setup { @memory = memories(:wedding) }

  test "only accepts known statuses" do
    assert_not VideoRender.new(memory: @memory, status: "exploded").valid?
    assert VideoRender.new(memory: @memory, status: "queued").valid?
  end

  test "progress stays within 0..100" do
    assert_not VideoRender.new(memory: @memory, progress: 101).valid?
    assert_not VideoRender.new(memory: @memory, progress: -1).valid?
  end

  test "lifecycle helpers" do
    video_render = @memory.video_renders.create!(status: "queued")
    video_render.mark_processing!
    assert video_render.processing?
    assert video_render.started_at

    video_render.mark_failed!("Lỗi thử")
    assert video_render.failed?
    assert video_render.finished?
    assert_equal "Lỗi thử", video_render.error_message
  end

  test "download filename is ascii" do
    video_render = @memory.video_renders.create!(status: "queued")
    assert_match(/\A6-nam-ngay-cuoi-\d+\.mp4\z/, video_render.download_filename)
  end

  test "memory status follows renders" do
    video_render = @memory.video_renders.create!(status: "processing")
    @memory.refresh_status!
    assert_equal "rendering", @memory.reload.status
    video_render.update!(status: "completed")
    @memory.refresh_status!
    assert_equal "ready", @memory.reload.status
  end
end
