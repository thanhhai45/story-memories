require "test_helper"

class CleanupTemporaryFilesJobTest < ActiveJob::TestCase
  test "removes stale temp directories and fails stuck jobs" do
    root = Rails.root.join(Videos::MemoryRenderer::TMP_ROOT)
    stale = root.join("render-999-stale")
    FileUtils.mkdir_p(stale)
    FileUtils.touch(stale, mtime: 1.day.ago.to_time)

    memory = memories(:wedding)
    stuck = memory.video_renders.create!(status: "processing")
    stuck.update_column(:updated_at, 3.hours.ago)
    story = memory.stories.create!(status: "generating")
    story.update_column(:updated_at, 1.hour.ago)

    CleanupTemporaryFilesJob.perform_now

    assert_not stale.exist?
    assert stuck.reload.failed?
    assert story.reload.failed?
  end
end
