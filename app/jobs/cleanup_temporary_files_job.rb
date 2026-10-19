require "fileutils"

# Dọn thư mục tạm còn sót (ví dụ worker bị kill giữa chừng) và đánh dấu
# các render/story bị treo là lỗi để người dùng có thể tạo lại.
class CleanupTemporaryFilesJob < ApplicationJob
  queue_as :default

  STALE_TMP_AFTER = 6.hours
  STUCK_RENDER_AFTER = 2.hours
  STUCK_STORY_AFTER = 30.minutes

  def perform
    remove_stale_directories
    fail_stuck_renders
    fail_stuck_stories
  end

  private

  def remove_stale_directories
    root = Rails.root.join(Videos::MemoryRenderer::TMP_ROOT)
    return unless root.directory?
    root.children.each do |path|
      next unless path.directory? && path.basename.to_s.start_with?("render-")
      FileUtils.rm_rf(path) if path.mtime < STALE_TMP_AFTER.ago
    end
  end

  def fail_stuck_renders
    VideoRender.active.where(updated_at: ...STUCK_RENDER_AFTER.ago).find_each do |video_render|
      video_render.mark_failed!("Quá trình dựng bị gián đoạn. Vui lòng tạo video lại.")
      video_render.memory.refresh_status!
    end
  end

  def fail_stuck_stories
    Story.in_progress.where(updated_at: ...STUCK_STORY_AFTER.ago)
         .update_all(status: "failed", error_message: "Quá trình tạo bị gián đoạn. Vui lòng thử lại.", updated_at: Time.current)
  end
end
