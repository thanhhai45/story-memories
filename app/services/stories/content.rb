module Stories
  # Chuẩn hóa + kiểm tra cấu trúc nội dung câu chuyện (dùng chung cho
  # kết quả AI, bản nháp tự động và chỉnh sửa tay).
  #
  #   {
  #     "title" => "6 năm cùng nhau", "subtitle" => "2020 — 2026",
  #     "scenes" => [{ "title" => "...", "narration" => "...", "photo_positions" => [1, 2, 3] }],
  #     "ending" => "..."
  #   }
  module Content
    MAX_SCENES = 6
    LIMITS = { title: 80, subtitle: 80, scene_title: 80, narration: 320, ending: 300 }.freeze

    module_function

    def normalize(raw, photo_count:)
      raw = deep_stringify(raw)
      scenes = raw["scenes"]
      scenes = scenes.values if scenes.is_a?(Hash) # form gửi dạng {"0" => {...}}

      normalized_scenes = Array(scenes).filter_map do |scene|
        next unless scene.is_a?(Hash)
        item = {
          "title" => clip(scene["title"], LIMITS[:scene_title]),
          "narration" => clip(scene["narration"], LIMITS[:narration]),
          "photo_positions" => positions(scene["photo_positions"], photo_count)
        }
        next if item["title"].empty? && item["narration"].empty? && item["photo_positions"].empty?
        item
      end.first(MAX_SCENES)

      {
        "title" => clip(raw["title"], LIMITS[:title]),
        "subtitle" => clip(raw["subtitle"], LIMITS[:subtitle]),
        "scenes" => normalized_scenes,
        "ending" => clip(raw["ending"], LIMITS[:ending])
      }
    end

    def errors_for(content)
      content = deep_stringify(content)
      errors = []
      errors << "Tiêu đề không được để trống" if content["title"].to_s.strip.empty?
      errors << "Danh sách đoạn không hợp lệ" unless content["scenes"].is_a?(Array)
      Array(content["scenes"]).each_with_index do |scene, index|
        unless scene.is_a?(Hash) && scene["photo_positions"].is_a?(Array)
          errors << "Đoạn #{index + 1} không hợp lệ"
        end
      end
      errors
    end

    def positions(value, photo_count)
      list = value.is_a?(String) ? value.split(/[^\d]+/) : Array(value)
      list.filter_map { |v| Integer(v.to_s, exception: false) }
          .select { |n| n.between?(1, [ photo_count.to_i, 0 ].max) }
          .uniq
    end

    def clip(value, limit)
      text = value.is_a?(String) || value.is_a?(Numeric) ? value.to_s : ""
      text = text.unicode_normalize(:nfc).gsub(/[[:cntrl:]]/, " ").squeeze(" ").strip
      text.length > limit ? text[0, limit - 1].rstrip + "…" : text
    end

    def deep_stringify(value)
      value = value.to_unsafe_h if value.respond_to?(:to_unsafe_h)
      case value
      when Hash then value.each_with_object({}) { |(k, v), h| h[k.to_s] = deep_stringify(v) }
      when Array then value.map { |v| deep_stringify(v) }
      else value
      end
    end
  end
end
