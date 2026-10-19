class VideoRendersController < ApplicationController
  before_action :set_memory

  rate_limit to: 6, within: 10.minutes, only: :create,
             with: -> { too_many_requests("Bạn đã tạo nhiều video liên tiếp. Hãy đợi vài phút.") }

  def create
    unless @memory.ready_for_render?
      redirect_to memory_path(@memory, anchor: "video"), status: :see_other,
                  alert: "Cần ít nhất #{Memory::MIN_PHOTOS_FOR_VIDEO} ảnh và một câu chuyện đã lưu trước khi dựng video."
      return
    end

    if (running = @memory.video_renders.active.recent.first)
      redirect_to memory_video_render_path(@memory, running), status: :see_other, notice: "Video đang được dựng."
      return
    end

    template = VideoTemplate.active.find_by(id: render_params[:video_template_id]) || @memory.effective_template
    music = render_params[:music_track].presence_in(MusicLibrary.keys) || @memory.effective_music_track

    video_render = @memory.video_renders.create!(
      story: @memory.current_story, video_template: template, music_track: music, status: "queued"
    )
    @memory.update(video_template: template, music_track: music)
    @memory.refresh_status!
    RenderVideoJob.perform_later(video_render.id)

    redirect_to memory_video_render_path(@memory, video_render), status: :see_other
  end

  def show
    @video_render = @memory.video_renders.find(params[:id])
  end

  private

  def render_params
    params.fetch(:video_render, {}).permit(:video_template_id, :music_track)
  end
end
