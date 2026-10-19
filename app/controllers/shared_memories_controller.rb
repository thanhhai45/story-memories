# Trang xem công khai bằng token khó đoán. Không có nút sửa, không lộ lỗi,
# prompt hay dữ liệu nội bộ. Link file video có hạn dùng ngắn (xem SharedMemoriesHelper).
class SharedMemoriesController < ApplicationController
  layout "shared"
  before_action :set_privacy_headers

  def show
    @memory = Memory.find_shared(params[:token])
    return render(:unavailable, status: :not_found) unless @memory

    @video_render = @memory.latest_completed_render
    @story = @video_render&.story || @memory.current_story
  end

  private

  def set_privacy_headers
    response.headers["X-Robots-Tag"] = "noindex, nofollow"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["Cache-Control"] = "private, no-store"
  end
end
