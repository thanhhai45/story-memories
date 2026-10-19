module Videos
  # Chuyển nội dung Story (JSON) + danh sách ảnh đã sắp xếp thành timeline
  # các phân đoạn có thời lượng rõ ràng. Không đụng tới file hay FFmpeg,
  # nên dễ kiểm thử.
  #
  #   photos: mảng hash { id:, caption: } theo đúng thứ tự người dùng sắp xếp.
  #           photo_positions trong Story là chỉ số 1-based của mảng này.
  class TimelineBuilder
    Timeline = Struct.new(:segments, keyword_init: true) do
      def total_duration = segments.sum { |s| s[:duration] }
      def photo_segments = segments.select { |s| s[:kind] == "photo" }
    end

    MOTIONS = %w[zoom_in pan_right zoom_out pan_left].freeze
    # Template có thể chọn danh sách riêng (config["motions"]) trong số này
    ALL_MOTIONS = (MOTIONS + %w[pan_up pan_down drift bounce]).freeze
    MIN_PHOTO_DURATION = 2.2

    def initialize(content:, photos:, config:, memory_title: nil)
      @content = content || {}
      @photos = Array(photos)
      @config = config || {}
      @memory_title = memory_title
    end

    def call
      raise Videos::Error.new("no photos", user_message: "Cần ít nhất 1 ảnh để dựng video.") if @photos.empty?

      chapters = assign_photos_to_chapters
      photo_duration = fitted_photo_duration(chapters)
      cover_id = @photos.first[:id]

      segments = []
      segments << {
        kind: "title", duration: num("title_duration", 4.5),
        title: text(@content["title"]).presence || @memory_title.to_s,
        subtitle: text(@content["subtitle"]), photo_id: cover_id
      }

      motions = Array(@config["motions"] || @config[:motions]).map(&:to_s) & ALL_MOTIONS
      motions = MOTIONS if motions.empty?
      motion_index = 0
      chapters.each do |chapter|
        if chapter[:title].present? || chapter[:narration].present?
          segments << {
            kind: "chapter", duration: chapter_duration(chapter[:narration]),
            title: chapter[:title], narration: chapter[:narration],
            photo_id: chapter[:photos].first&.dig(:id) || cover_id
          }
        end
        chapter[:photos].each do |photo|
          segments << {
            kind: "photo", duration: photo_duration, photo_id: photo[:id],
            caption: text(photo[:caption]), motion: motions[motion_index % motions.length]
          }
          motion_index += 1
        end
      end

      ending = text(@content["ending"])
      if ending.present?
        segments << {
          kind: "ending", duration: num("ending_duration", 5.0), text: ending,
          signature: text(@content["title"]).presence || @memory_title.to_s,
          photo_id: @photos.last[:id]
        }
      end

      Timeline.new(segments:)
    end

    private

    def assign_photos_to_chapters
      scenes = Array(@content["scenes"]).select { |s| s.is_a?(Hash) }
      used = {}
      chapters = scenes.map do |scene|
        positions = Array(scene["photo_positions"]).filter_map { |p| Integer(p, exception: false) }
        photos = positions.filter_map do |pos|
          next if pos < 1 || pos > @photos.length || used[pos]
          used[pos] = true
          @photos[pos - 1]
        end
        { title: text(scene["title"]), narration: text(scene["narration"]), photos: }
      end

      leftovers = @photos.each_with_index.reject { |_, i| used[i + 1] }.map(&:first)
      if chapters.empty?
        chapters << { title: nil, narration: nil, photos: leftovers }
      elsif leftovers.any?
        chapters.last[:photos].concat(leftovers)
      end
      chapters
    end

    def fitted_photo_duration(chapters)
      wanted = num("photo_duration", 3.5)
      max_total = num("max_duration", 95.0)
      fixed = num("title_duration", 4.5) + num("ending_duration", 5.0) +
              chapters.sum { |c| c[:title].present? || c[:narration].present? ? chapter_duration(c[:narration]) : 0 }
      available = max_total - fixed
      per_photo = available / @photos.length
      per_photo.clamp([ MIN_PHOTO_DURATION, wanted ].min, wanted).round(2)
    end

    def chapter_duration(narration)
      base = num("chapter_duration", 4.0)
      (1.8 + narration.to_s.length / 22.0).clamp(base, 9.0).round(2)
    end

    def num(key, default)
      value = @config[key] || @config[key.to_sym]
      value.nil? ? default : value.to_f
    end

    def text(value)
      Videos::TextLayout.clean(value)
    end
  end
end
