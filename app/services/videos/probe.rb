require "json"

module Videos
  # Đọc metadata file video bằng ffprobe và xác nhận output hợp lệ.
  class Probe
    Info = Struct.new(:duration, :width, :height, :video_codec, :audio_codec, :size, keyword_init: true) do
      def to_h_for_storage
        { "duration" => duration.round(2), "width" => width, "height" => height,
          "video_codec" => video_codec, "audio_codec" => audio_codec, "size" => size }
      end
    end

    def self.call(path) = new(path).call

    def initialize(path)
      @path = path.to_s
    end

    def call
      raise Videos::Error, "output missing: #{@path}" unless File.file?(@path) && File.size(@path).positive?

      result = Command.run!("ffprobe", "-v", "error", "-print_format", "json",
                            "-show_format", "-show_streams", @path, timeout: 30)
      data = JSON.parse(result.stdout)
      video = Array(data["streams"]).find { |s| s["codec_type"] == "video" }
      audio = Array(data["streams"]).find { |s| s["codec_type"] == "audio" }
      duration = data.dig("format", "duration").to_f

      raise Videos::Error, "no video stream in output" unless video
      raise Videos::Error, "output has zero duration" unless duration.positive?

      Info.new(duration:, width: video["width"].to_i, height: video["height"].to_i,
               video_codec: video["codec_name"], audio_codec: audio&.dig("codec_name"),
               size: File.size(@path))
    rescue JSON::ParserError => e
      raise Videos::Error, "ffprobe returned invalid json: #{e.message}"
    end
  end
end
