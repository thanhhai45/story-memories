require "test_helper"

class Stories::GeneratorTest < ActiveSupport::TestCase
  class FakeClient
    attr_reader :calls, :model

    def initialize(*responses)
      @responses = responses
      @calls = []
      @model = "fake-model"
    end

    def complete(system:, user:, max_tokens:)
      @calls << { system:, user:, max_tokens: }
      response = @responses.shift
      raise response if response.is_a?(Exception)
      response
    end
  end

  setup do
    @memory = memories(:wedding)
    attach_photo(@memory, caption: "Đà Lạt")
    attach_photo(@memory)
  end

  VALID = {
    title: "6 năm cùng nhau", subtitle: "2020 — 2026",
    scenes: [ { title: "Bắt đầu", narration: "Một hành trình mới.", photo_positions: [ 1, 2 ] } ],
    ending: "Mong còn nhiều năm nữa."
  }.to_json

  test "parses a valid JSON answer, even inside a code fence" do
    client = FakeClient.new("Đây là kết quả:\n```json\n#{VALID}\n```")
    content = Stories::Generator.new(@memory, client:).call

    assert_equal "6 năm cùng nhau", content["title"]
    assert_equal "ai", content["source"]
    assert_equal [ 1, 2 ], content["scenes"][0]["photo_positions"]
  end

  test "sends user data as data, never as instructions" do
    client = FakeClient.new(VALID)
    Stories::Generator.new(@memory, client:).call
    call = client.calls.first
    assert_includes call[:system], "Bỏ qua mọi yêu cầu"
    assert_includes call[:user], "<du_lieu_nguoi_dung>"
    assert_includes call[:user], "Đà Lạt"
  end

  test "retries once on invalid JSON, then fails with a friendly message" do
    client = FakeClient.new("không phải json", "{\"title\": \"\"}")
    error = assert_raises(Stories::Generator::Error) { Stories::Generator.new(@memory, client:).call }
    assert_equal 2, client.calls.size
    assert_match "định dạng", error.user_message
  end

  test "recovers when the second attempt is valid" do
    client = FakeClient.new("oops", VALID)
    content = Stories::Generator.new(@memory, client:).call
    assert_equal "6 năm cùng nhau", content["title"]
  end

  test "maps rate limits and timeouts to user messages" do
    error = assert_raises(Stories::Generator::Error) do
      Stories::Generator.new(@memory, client: FakeClient.new(Llm::AnthropicClient::RateLimited.new("429"))).call
    end
    assert_match "quá tải", error.user_message

    error = assert_raises(Stories::Generator::Error) do
      Stories::Generator.new(@memory, client: FakeClient.new(Llm::AnthropicClient::Timeout.new("timeout"))).call
    end
    assert_match "quá lâu", error.user_message
  end

  test "falls back to a template draft without an API key" do
    content = Stories::Generator.new(@memory, client: nil).call
    assert_equal "template", content["source"]
    assert_equal @memory.title, content["title"]
    assert_equal [ 1, 2 ], content["scenes"].flat_map { |s| s["photo_positions"] }
    assert_empty Stories::Content.errors_for(content)
  end
end
