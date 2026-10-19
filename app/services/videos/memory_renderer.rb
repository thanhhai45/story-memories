require "tmpdir"
require "fileutils"

module Videos
  # Điều phối việc dựng video cho một VideoRender:
  # tải ảnh đã chuẩn hóa -> dựng timeline -> FFmpeg -> kiểm tra bằng ffprobe -> gắn MP4.
  # Thư mục tạm luôn bị xóa khi xong, kể cả khi lỗi.
  class MemoryRenderer
    TMP_ROOT = "tmp/renders".freeze

    def initialize(video_render)
      @video_render = video_render
      @memory = video_render.memory
    end

    # Yield phần trăm tiến độ (0..100). Trả về metadata của file output.
    def call(&on_progress)
      on_progress ||= ->(_) {}
      story = @video_render.story || @memory.current_story
      unless story&.completed?
        raise Videos::Error.new("no completed story", user_message: "Chưa có lời dẫn. Hãy tạo và lưu câu chuyện trước khi dựng video.")
      end

      photos = @memory.memory_photos.includes(image_attachment: :blob).to_a
      raise Videos::Error.new("no photos", user_message: "Cần ít nhất 1 ảnh để dựng video.") if photos.empty?

      template = @video_render.video_template || @memory.effective_template
      raise Videos::Error.new("no template", user_message: "Chưa có template video.") unless template
      config = template.configuration

      music_path = nil
      if @video_render.music_track.present?
        music_path = MusicLibrary.path_for(@video_render.music_track)
        raise Videos::Error.new("music file missing", user_message: "Không tìm thấy file nhạc nền đã chọn.") unless music_path
      end

      root = Rails.root.join(TMP_ROOT)
      FileUtils.mkdir_p(root)
      Dir.mktmpdir("render-#{@video_render.id}-", root) do |dir|
        photo_paths = download_photos(photos, dir) { |percent| on_progress.call((percent * 0.1).floor) }

        timeline = TimelineBuilder.new(
          content: story.generated_content,
          photos: photos.map { |photo| { id: photo.id, caption: photo.caption } },
          config:, memory_title: @memory.title
        ).call

        output, info = Renderer.new(
          timeline:, photo_paths:, config:,
          work_dir: File.join(dir, "work"),
          fonts_dir: Rails.root.join("app/assets/fonts"),
          music_path:,
          on_progress: ->(percent) { on_progress.call(10 + (percent * 0.85).floor) }
        ).call

        File.open(output, "rb") do |file|
          @video_render.output_video.attach(io: file, filename: @video_render.download_filename,
                                            content_type: "video/mp4", identify: false)
        end
        on_progress.call(100)
        info.to_h_for_storage.merge("segments" => timeline.segments.length, "photos" => photos.length)
      end
    end

    private

    def download_photos(photos, dir)
      folder = File.join(dir, "photos")
      FileUtils.mkdir_p(folder)
      photos.each_with_index.to_h do |photo, index|
        path = File.join(folder, format("photo_%03d.jpg", index + 1))
        begin
          variant = photo.image.variant(:render).processed
          File.open(path, "wb") { |file| variant.download { |chunk| file.write(chunk) } }
        rescue StandardError => e
          Rails.logger.error("[Videos::MemoryRenderer] photo #{photo.id} failed: #{e.class}: #{e.message.truncate(200)}")
          raise Videos::Error.new("photo #{photo.id} unreadable",
                                  user_message: "Ảnh số #{index + 1} không đọc được. Hãy xóa ảnh đó hoặc tải lại ảnh khác.")
        end
        yield(((index + 1) * 100.0 / photos.length).floor) if block_given?
        [ photo.id.to_s, path ]
      end
    end
  end
end
