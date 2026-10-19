module Stories
  # Bản nháp không cần AI: dùng khi chưa cấu hình ANTHROPIC_API_KEY
  # (hoặc để chạy thử offline). Chỉ dùng dữ liệu người dùng đã nhập.
  class FallbackWriter
    CHAPTER_TITLES = {
      "romantic" => [ "Ngày chúng ta bắt đầu", "Những tháng năm bên nhau", "Những điều giản dị", "Hôm nay và mãi sau" ],
      "playful" => [ "Màn mở đầu", "Những chuyến phiêu lưu", "Cười thật nhiều", "Còn nhiều chuyện vui phía trước" ],
      "nostalgic" => [ "Ngày ấy", "Những mùa đã qua", "Điều còn ở lại", "Nhìn lại và mỉm cười" ]
    }.freeze

    ENDINGS = {
      "romantic" => "Cảm ơn vì đã cùng nhau đi qua tất cả. Mong còn thật nhiều năm tháng bên nhau.",
      "playful" => "Hành trình còn dài, và chắc chắn sẽ còn nhiều tiếng cười hơn nữa.",
      "nostalgic" => "Có những khoảnh khắc đã qua, nhưng ký ức thì vẫn luôn ở lại."
    }.freeze

    GENERIC_NARRATION = [
      "Những khoảnh khắc nhỏ, góp lại thành một câu chuyện đáng nhớ.",
      "Mỗi bức ảnh là một lần ta muốn giữ thời gian lại lâu hơn.",
      "Có vui, có lo, nhưng luôn có nhau.",
      "Và câu chuyện vẫn đang tiếp tục được viết."
    ].freeze

    def initialize(memory, photos)
      @memory = memory
      @photos = photos
    end

    def call
      count = @photos.size
      chapter_count = count.zero? ? 1 : (count / 6.0).ceil.clamp(1, 4)
      groups = split_positions(count, chapter_count)
      sentences = @memory.story_notes.to_s.split(/(?<=[.!?…])\s+/).map(&:strip).reject(&:empty?)
      titles = CHAPTER_TITLES.fetch(@memory.style, CHAPTER_TITLES["romantic"])

      scenes = groups.each_with_index.map do |positions, index|
        {
          "title" => titles[index] || titles.last,
          "narration" => narration_for(index, chapter_count, sentences),
          "photo_positions" => positions
        }
      end

      ending = ENDINGS.fetch(@memory.style, ENDINGS["romantic"])
      ending = "#{@memory.person_names} — #{ending}" if @memory.person_names.present?

      Content.normalize({
        "title" => @memory.title,
        "subtitle" => @memory.period_label || @memory.occasion_label,
        "scenes" => scenes,
        "ending" => ending
      }, photo_count: count).merge("source" => "template")
    end

    private

    def split_positions(count, parts)
      return [ [] ] if count.zero?
      (1..count).to_a.each_slice((count / parts.to_f).ceil).to_a
    end

    def narration_for(index, total, sentences)
      return GENERIC_NARRATION[index % GENERIC_NARRATION.length] if sentences.empty?
      per = (sentences.length / total.to_f).ceil
      chunk = sentences.slice(index * per, per)
      chunk.present? ? chunk.join(" ") : GENERIC_NARRATION[index % GENERIC_NARRATION.length]
    end
  end
end
