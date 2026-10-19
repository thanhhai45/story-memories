class MemoriesController < ApplicationController
  before_action :set_memory, only: %i[show edit update destroy]

  def index
    @memories = Memory.recent.includes(memory_photos: { image_attachment: :blob }).limit(100)
  end

  def show
    @photos = @memory.memory_photos.includes(image_attachment: :blob)
    @story = @memory.current_story
    @latest_story = @memory.latest_story
    @renders = @memory.video_renders.recent.includes(:video_template).limit(5)
    @latest_completed_render = @memory.latest_completed_render
    @templates = VideoTemplate.active
  end

  def new
    @memory = Memory.new(occasion: "anniversary", style: "romantic")
  end

  def create
    @memory = Memory.new(memory_params)
    if @memory.save
      redirect_to memory_path(@memory, anchor: "photos"), notice: "Đã tạo kỷ niệm. Giờ hãy thêm ảnh."
    else
      render :new, status: 422
    end
  end

  def edit
  end

  def update
    if @memory.update(memory_params)
      redirect_to @memory, notice: "Đã lưu thay đổi."
    else
      render :edit, status: 422
    end
  end

  def destroy
    @memory.destroy!
    redirect_to root_path, status: :see_other, notice: "Đã xóa kỷ niệm cùng toàn bộ ảnh và video."
  end

  private

  def memory_params
    params.require(:memory).permit(:title, :occasion, :start_date, :end_date, :person_names,
                                   :story_notes, :style, :video_template_id, :music_track)
  end
end
