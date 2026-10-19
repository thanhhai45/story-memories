class MemorySharingsController < ApplicationController
  before_action :set_memory

  def create
    @memory.enable_sharing!
    redirect_to memory_path(@memory, anchor: "share"), status: :see_other, notice: "Đã bật link chia sẻ."
  end

  def destroy
    @memory.disable_sharing!
    redirect_to memory_path(@memory, anchor: "share"), status: :see_other,
                notice: "Đã tắt chia sẻ. Link cũ không còn xem được."
  end

  def rotate
    @memory.regenerate_share_token!
    redirect_to memory_path(@memory, anchor: "share"), status: :see_other,
                notice: "Đã tạo link mới. Link cũ không còn dùng được."
  end
end
