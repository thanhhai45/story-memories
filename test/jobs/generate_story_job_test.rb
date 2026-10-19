require "test_helper"

class GenerateStoryJobTest < ActiveJob::TestCase
  setup do
    @previous_key = ENV.delete("ANTHROPIC_API_KEY")
    @memory = memories(:wedding)
    attach_photo(@memory)
  end

  teardown { ENV["ANTHROPIC_API_KEY"] = @previous_key if @previous_key }

  test "completes with a template draft when no API key is configured" do
    story = @memory.stories.create!(status: "pending")
    GenerateStoryJob.perform_now(story.id)

    story.reload
    assert story.completed?, story.error_message
    assert_equal "template", story.source
    assert story.generated_at
  end

  test "skips stories that are already finished" do
    story = stories(:wedding_story)
    before = story.generated_content
    GenerateStoryJob.perform_now(story.id)
    assert_equal before, story.reload.generated_content
  end
end
