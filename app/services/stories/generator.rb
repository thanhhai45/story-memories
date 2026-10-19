require "json"

module Stories
  # Sinh lời dẫn cho một Memory.
  # - Có ANTHROPIC_API_KEY: gọi LLM phía server, parse + validate JSON, thử lại 1 lần nếu sai schema.
  # - Không có key: tạo bản nháp từ FallbackWriter để luồng end-to-end vẫn chạy được.
  # Không bao giờ ghi API key hay nội dung tâm sự vào log.
  class Generator
    class Error < StandardError
      attr_reader :user_message

      def initialize(message, user_message:)
        super(message)
        @user_message = user_message
      end
    end

    MAX_ATTEMPTS = 2
    MAX_TOKENS = 1800

    def initialize(memory, client: Llm::AnthropicClient.from_env, logger: Rails.logger)
      @memory = memory
      @client = client
      @logger = logger
    end

    def call
      photos = @memory.memory_photos.to_a
      return FallbackWriter.new(@memory, photos).call if @client.nil?

      input = Prompt.input_for(@memory, photos)
      attempts = 0
      begin
        attempts += 1
        text = @client.complete(system: Prompt::SYSTEM, user: Prompt.user_message(input), max_tokens: MAX_TOKENS)
        content = Content.normalize(parse_json(text), photo_count: photos.size)
        problems = Content.errors_for(content)
        problems << "no scenes" if content["scenes"].empty?
        raise JSON::ParserError, problems.join(", ") if problems.any?
        content.merge("source" => "ai", "model" => @client.model)
      rescue JSON::ParserError => e
        @logger.warn("[Stories::Generator] invalid AI output (attempt #{attempts}): #{e.message.truncate(200)}")
        retry if attempts < MAX_ATTEMPTS
        raise Error.new("invalid AI output", user_message: "AI trả về nội dung không đúng định dạng. Hãy bấm tạo lại.")
      end
    rescue Llm::AnthropicClient::RateLimited => e
      raise Error.new(e.message, user_message: "Dịch vụ AI đang quá tải. Vui lòng thử lại sau ít phút.")
    rescue Llm::AnthropicClient::Timeout => e
      raise Error.new(e.message, user_message: "AI phản hồi quá lâu. Vui lòng thử lại.")
    rescue Llm::AnthropicClient::Error => e
      raise Error.new(e.message, user_message: "Không kết nối được dịch vụ AI. Kiểm tra cấu hình API key rồi thử lại.")
    end

    private

    # Chấp nhận cả khi model lỡ bọc JSON trong ```json ... ```
    def parse_json(text)
      cleaned = text.to_s.gsub(/```(?:json)?/i, "")
      start = cleaned.index("{")
      finish = cleaned.rindex("}")
      raise JSON::ParserError, "no json object" unless start && finish && finish > start
      parsed = JSON.parse(cleaned[start..finish])
      raise JSON::ParserError, "not an object" unless parsed.is_a?(Hash)
      parsed
    end
  end
end
