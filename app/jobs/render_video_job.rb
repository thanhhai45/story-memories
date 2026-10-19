class RenderVideoJob < ApplicationJob
  queue_as :video

  # FFmpeg ngốn CPU/RAM: chỉ dựng một video mỗi lần cho mỗi kỷ niệm.
  limits_concurrency to: 1, key: ->(render_id) { "render-memory-#{VideoRender.where(id: render_id).pick(:memory_id)}" },
                     duration: 45.minutes

  PROGRESS_STEP = 2

  def perform(render_id)
    video_render = VideoRender.find_by(id: render_id)
    return unless video_render&.queued?

    video_render.mark_processing!
    video_render.memory.refresh_status!

    last_progress = 0
    metadata = Videos::MemoryRenderer.new(video_render).call do |percent|
      percent = percent.to_i.clamp(0, 99)
      next if percent < last_progress + PROGRESS_STEP
      last_progress = percent
      video_render.update_column(:progress, percent)
    end

    video_render.mark_completed!(metadata:)
  rescue Videos::Error => e
    Rails.logger.error("[RenderVideoJob] render=#{render_id} failed: #{e.message.truncate(500)}")
    video_render&.mark_failed!(e.user_message)
  rescue StandardError => e
    Rails.logger.error("[RenderVideoJob] render=#{render_id} crashed: #{e.class}: #{e.message.truncate(500)}")
    video_render&.mark_failed!("Có lỗi không mong muốn khi dựng video. Vui lòng thử lại.")
    raise
  ensure
    video_render&.memory&.refresh_status!
  end
end
