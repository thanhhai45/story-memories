class MemoryStoriesController < ApplicationController
  before_action :set_memory

  rate_limit to: 10, within: 10.minutes, only: :create,
             with: -> { too_many_requests("Bạn đã tạo lại nhiều lần. Hãy đợi vài phút để tiết kiệm chi phí AI.") }

  def show
    @latest_story = @memory.latest_story
    @story = @memory.current_story || @memory.stories.new
    @photos = @memory.memory_photos.includes(image_attachment: :blob)
  end

  def create
    if @memory.stories.in_progress.exists?
      redirect_to memory_story_path(@memory), status: :see_other, notice: "Câu chuyện đang được viết, vui lòng đợi."
      return
    end

    story = @memory.stories.create!(
      status: "pending",
      prompt_data: Stories::Prompt.input_for(@memory, @memory.memory_photos.to_a)
    )
    GenerateStoryJob.perform_later(story.id)
    redirect_to memory_story_path(@memory), status: :see_other
  end

  def update
    @story = @memory.current_story || @memory.stories.new
    if @story.apply_edits(story_params, photo_count: @memory.memory_photos.size)
      redirect_to memory_story_path(@memory), status: :see_other, notice: "Đã lưu nội dung."
    else
      @latest_story = @memory.latest_story
      @photos = @memory.memory_photos.includes(image_attachment: :blob)
      render :show, status: 422
    end
  end

  private

  def story_params
    params.require(:story).permit(:title, :subtitle, :ending, scenes: %i[title narration photo_positions])
  end
end
