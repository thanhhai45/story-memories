require "net/http"
require "json"

module Llm
  # Client tối giản cho Anthropic Messages API, gọi từ server (không bao giờ từ trình duyệt).
  class AnthropicClient
    class Error < StandardError; end
    class RateLimited < Error; end
    class Timeout < Error; end

    ENDPOINT = URI("https://api.anthropic.com/v1/messages").freeze
    API_VERSION = "2023-06-01".freeze
    DEFAULT_MODEL = "claude-sonnet-5-5".freeze

    attr_reader :model

    def self.from_env
      key = ENV["ANTHROPIC_API_KEY"].to_s.strip
      return nil if key.empty?
      new(api_key: key, model: ENV["LLM_MODEL"].presence || DEFAULT_MODEL,
          workspace_id: ENV["ANTHROPIC_WORKSPACE_ID"].to_s.strip.presence)
    end

    # workspace_id: chỉ cần khi API key không gắn với workspace nào
    def initialize(api_key:, model: DEFAULT_MODEL, workspace_id: nil, open_timeout: 10, read_timeout: 90)
      @api_key = api_key
      @model = model
      @workspace_id = workspace_id
      @open_timeout = open_timeout
      @read_timeout = read_timeout
    end

    # Không gửi temperature: các model mới (claude-*-5-5) báo lỗi 400 nếu có
    def complete(system:, user:, max_tokens: 1500)
      request = Net::HTTP::Post.new(ENDPOINT)
      request["x-api-key"] = @api_key
      request["anthropic-version"] = API_VERSION
      request["anthropic-workspace-id"] = @workspace_id if @workspace_id
      request["content-type"] = "application/json"
      request.body = JSON.generate(
        model: @model, max_tokens:, system:,
        messages: [ { role: "user", content: user } ]
      )

      response = Net::HTTP.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true,
                                 open_timeout: @open_timeout, read_timeout: @read_timeout,
                                 write_timeout: 30) { |http| http.request(request) }
      handle(response)
    rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout
      raise Timeout, "Anthropic API timeout"
    rescue SocketError, SystemCallError, OpenSSL::SSL::SSLError, EOFError, IOError => e
      raise Error, "Anthropic API connection error: #{e.class}"
    end

    # Không đưa object này vào log (tránh lộ key)
    def inspect = "#<#{self.class.name} model=#{@model}>"

    private

    def handle(response)
      code = response.code.to_i
      case code
      when 200
        body = JSON.parse(response.body)
        Array(body["content"]).select { |block| block["type"] == "text" }.map { |block| block["text"] }.join
      when 429, 529
        raise RateLimited, "Anthropic API rate limited (#{code})"
      else
        # error.message của API không chứa key, an toàn để log
        type, detail = begin
          JSON.parse(response.body)["error"]&.values_at("type", "message")
        rescue JSON::ParserError
          nil
        end
        raise Error, "Anthropic API error #{code} #{type} #{detail.to_s.truncate(300)}".strip
      end
    rescue JSON::ParserError
      raise Error, "Anthropic API returned invalid JSON"
    end
  end
end
