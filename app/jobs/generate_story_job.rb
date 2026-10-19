class GenerateStoryJob < ApplicationJob
  queue_as :ai

  def perform(story_id)
    story = Story.find_by(id: story_id)
    return unless story&.in_progress?

    story.update!(status: "generating", error_message: nil)
    content = Stories::Generator.new(story.memory).call
    story.update!(status: "completed", generated_content: content, generated_at: Time.current)
  rescue Stories::Generator::Error => e
    Rails.logger.warn("[GenerateStoryJob] story=#{story_id} failed: #{e.message}")
    story&.update_columns(status: "failed", error_message: e.user_message, updated_at: Time.current)
  rescue StandardError => e
    Rails.logger.error("[GenerateStoryJob] story=#{story_id} crashed: #{e.class}: #{e.message.truncate(300)}")
    story&.update_columns(status: "failed", updated_at: Time.current,
                          error_message: "Có lỗi không mong muốn khi tạo câu chuyện. Vui lòng thử lại.")
    raise
  end
end
