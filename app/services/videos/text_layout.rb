module Videos
  # Ngắt dòng cho chữ hiển thị trong video (drawtext không tự xuống dòng).
  # Ước lượng độ rộng ký tự theo cỡ chữ; sau đó cân bằng độ dài các dòng
  # để tránh dòng cuối chỉ còn một chữ.
  module TextLayout
    module_function

    CHAR_WIDTH_RATIO = 0.56

    def clean(text)
      text.to_s.unicode_normalize(:nfc)
          .gsub(/[[:cntrl:]&&[^\n]]/, "")
          .gsub(/[ \t]+/, " ")
          .strip
    end

    def wrap(text, max_width:, font_size:, max_lines: 6)
      limit = [(max_width / (font_size * CHAR_WIDTH_RATIO)).floor, 8].max
      paragraphs = clean(text).split(/\n+/).map(&:strip).reject(&:empty?)
      lines = paragraphs.flat_map { |paragraph| balanced(paragraph, limit) }

      if lines.length > max_lines
        lines = lines.first(max_lines)
        lines[-1] = lines[-1].sub(/\s*\S*\z/, "") + "…"
      end
      lines
    end

    def balanced(paragraph, limit)
      lines = greedy(paragraph, limit)
      return lines if lines.length < 2

      low = [limit / 2, 8].max
      high = limit
      while low < high
        mid = (low + high) / 2
        greedy(paragraph, mid).length <= lines.length ? high = mid : low = mid + 1
      end
      greedy(paragraph, high)
    end

    def greedy(paragraph, limit)
      lines = []
      current = +""
      paragraph.split(" ").each do |word|
        word = word[0, limit] if word.length > limit
        if current.empty?
          current = word.dup
        elsif current.length + 1 + word.length <= limit
          current << " " << word
        else
          lines << current
          current = word.dup
        end
      end
      lines << current unless current.empty?
      lines
    end
  end
end
