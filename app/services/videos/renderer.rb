require "fileutils"

module Videos
  # Dựng MP4 từ timeline bằng FFmpeg theo template cố định.
  #
  # Quy trình cho mỗi phân đoạn:
  #   1. Ghép một khung hình tĩnh (PNG, gấp đôi độ phân giải đầu ra) gồm nền, ảnh, chữ.
  #   2. Biến khung tĩnh thành clip ngắn có chuyển động nhẹ (zoompan / Ken Burns).
  # Cuối cùng nối các clip bằng xfade, thêm nhạc nền (loudnorm + fade), xuất H.264/AAC.
  #
  # Mọi đường dẫn đều do hệ thống tạo trong work_dir; người dùng không thể truyền
  # tham số hay đường dẫn vào FFmpeg. Chữ được ghi ra file và đọc qua textfile=
  # với expansion=none nên không cần (và không thể) chèn cú pháp filter.
  class Renderer
    SUPERSAMPLE = 2

    DEFAULT_CONFIG = {
      "layout" => "cinematic",
      "width" => 1280, "height" => 720, "fps" => 30,
      "transition" => 0.7, "transition_style" => "fade",
      "max_zoom" => 1.12,
      "palette" => {
        "background" => "15121C", "text" => "FFFFFF", "muted" => "D9D2E3", "accent" => "E2C08D"
      },
      "fonts" => {
        "title" => "PlayfairDisplay-SemiBold.ttf", "italic" => "PlayfairDisplay-Italic.ttf",
        "body" => "BeVietnamPro-Light.ttf", "caption" => "BeVietnamPro-Regular.ttf"
      }
    }.freeze

    attr_reader :work_dir

    def initialize(timeline:, photo_paths:, config:, work_dir:, fonts_dir:, music_path: nil, on_progress: nil)
      @timeline = timeline
      @photo_paths = photo_paths.transform_keys(&:to_s)
      @config = deep_merge(DEFAULT_CONFIG, (config || {}).to_h.transform_keys(&:to_s))
      @work_dir = work_dir.to_s
      @fonts_dir = fonts_dir.to_s
      @music_path = music_path&.to_s
      @on_progress = on_progress
      @text_counter = 0
    end

    # Trả về [output_path, Probe::Info]
    def call
      FileUtils.mkdir_p(@work_dir)
      validate_inputs!

      segments = @timeline.segments
      steps = segments.length * 2 + 2
      done = 0

      clips = segments.each_with_index.map do |segment, index|
        still = compose_still(segment, index)
        report(done += 1, steps)
        last = index == segments.length - 1
        clip = render_clip(still, segment, index, extra: last ? 0 : transition)
        report(done += 1, steps)
        clip
      end

      output = File.join(@work_dir, "output.mp4")
      assemble(clips, segments, output)
      report(done += 1, steps)
      info = Probe.call(output)
      report(steps, steps)
      [output, info]
    end

    private

    # ---------- validation ----------

    def validate_inputs!
      @timeline.segments.each do |seg|
        next unless seg[:kind] == "photo"
        path = @photo_paths[seg[:photo_id].to_s]
        unless path && File.file?(path)
          raise Videos::Error.new("missing photo #{seg[:photo_id]}", user_message: "Thiếu file ảnh. Hãy tải lại ảnh rồi thử lại.")
        end
      end
      if @music_path && !File.file?(@music_path)
        raise Videos::Error.new("missing music #{@music_path}", user_message: "Không tìm thấy file nhạc nền đã chọn.")
      end
      %w[title body caption italic].each do |key|
        raise Videos::Error, "missing font #{font(key)}" unless File.file?(font(key))
      end
    end

    # ---------- config helpers ----------

    def width = @config["width"].to_i
    def height = @config["height"].to_i
    def fps = @config["fps"].to_i
    def transition = @config["transition"].to_f
    def layout = @config["layout"].to_s
    def album? = layout == "album"
    def big_w = width * SUPERSAMPLE
    def big_h = height * SUPERSAMPLE
    def color(key) = "0x" + @config.dig("palette", key).to_s.delete("#")
    def font(key) = File.join(@fonts_dir, @config.dig("fonts", key).to_s)
    def background_hex = color("background")

    def report(done, total)
      @on_progress&.call(((done.to_f / total) * 100).floor.clamp(0, 100))
    end

    # ---------- step 1: still frames ----------

    def compose_still(segment, index)
      out = File.join(@work_dir, format("still_%03d.png", index))
      inputs, chain = album? ? album_still(segment) : cinematic_still(segment)
      Command.run!("ffmpeg", "-y", "-loglevel", "error", *inputs,
                   "-filter_complex", chain, "-frames:v", "1", "-update", "1", out, timeout: 90)
      out
    rescue Videos::Error => e
      if segment[:kind] == "photo"
        raise Videos::Error.new(e.message, user_message: "Có ảnh không đọc được. Hãy xóa ảnh lỗi hoặc tải lại ảnh khác.")
      end
      raise
    end

    def photo_path(segment)
      segment[:photo_id] && @photo_paths[segment[:photo_id].to_s]
    end

    # Template A: nền tối từ chính ảnh làm mờ, ảnh đặt giữa, chữ trắng.
    def cinematic_still(segment)
      path = photo_path(segment)
      bg = if path
        darkness = segment[:kind] == "photo" ? -0.22 : -0.38
        "[0:v]scale=#{big_w}:#{big_h}:force_original_aspect_ratio=increase,crop=#{big_w}:#{big_h}," \
          "gblur=sigma=#{(big_h / 28.0).round(1)},eq=brightness=#{darkness}:saturation=0.7,vignette=PI/4[bg]"
      else
        "color=c=#{background_hex}:s=#{big_w}x#{big_h}:d=1,vignette=PI/4[bg]"
      end
      inputs = path ? ["-i", path] : []

      chain = case segment[:kind]
      when "photo"
        fg_w = (big_w * 0.92).round
        fg_h = (big_h * 0.90).round
        base = "#{bg};[0:v]scale=#{fg_w}:#{fg_h}:force_original_aspect_ratio=decrease[fg];" \
               "[bg][fg]overlay=(W-w)/2:(H-h)/2"
        caption = caption_filters(segment[:caption], color: color("text"), boxed: true)
        [base, *caption].join(",")
      else
        [ "#{bg};[bg]null", *card_text_filters(segment, dark: true) ].join(",")
      end
      [inputs, chain]
    end

    # Template B: giấy album, ảnh có viền trắng, hơi nghiêng, có bóng đổ.
    def album_still(segment)
      paper = "color=c=#{background_hex}:s=#{big_w}x#{big_h}:d=1,noise=alls=6:allf=u,vignette=PI/6"
      frame_inset = (big_h * 0.045).round
      frame = "drawbox=x=#{frame_inset}:y=#{frame_inset}:w=iw-#{frame_inset * 2}:h=ih-#{frame_inset * 2}:" \
              "color=#{color('accent')}@0.55:t=#{SUPERSAMPLE * 2}"

      if segment[:kind] == "photo"
        path = photo_path(segment)
        border = (big_h * 0.022).round
        margin = (big_h * 0.05).round
        has_caption = segment[:caption].present?
        max_w = (big_w * 0.80).round
        max_h = (big_h * (has_caption ? 0.70 : 0.78)).round
        angle = [-1.6, 1.2, -0.8, 1.8][segment[:photo_id].to_s.sum % 4] * Math::PI / 180
        shadow_off = (big_h * 0.012).round
        center_y = has_caption ? "(H-h)/2-#{(big_h * 0.05).round}" : "(H-h)/2"

        chain = [
          "#{paper},#{frame}[paper]",
          "[0:v]scale=#{max_w}:#{max_h}:force_original_aspect_ratio=decrease," \
          "pad=iw+#{border * 2}:ih+#{border * 2}:#{border}:#{border}:color=white,format=rgba," \
          "pad=iw+#{margin * 2}:ih+#{margin * 2}:#{margin}:#{margin}:color=black@0," \
          "rotate=#{angle.round(4)}:c=none:ow=rotw(#{angle.round(4)}):oh=roth(#{angle.round(4)}),split[card][sh]",
          "[sh]colorchannelmixer=rr=0:gg=0:bb=0:aa=0.38,gblur=sigma=#{(big_h / 90.0).round(1)}[shadow]",
          "[paper][shadow]overlay=(W-w)/2+#{shadow_off}:#{center_y}+#{shadow_off * 2}[withshadow]",
          ["[withshadow][card]overlay=(W-w)/2:#{center_y}",
           *caption_filters(segment[:caption], color: color("text"), boxed: false, font_key: "italic")].join(",")
        ].join(";")
        [["-i", path], chain]
      else
        [[], [paper, frame, *card_text_filters(segment, dark: false)].join(",")]
      end
    end

    # ---------- text ----------

    def card_text_filters(segment, dark:)
      title_color = color("text")
      body_color = color("muted")
      accent = color("accent")
      blocks = case segment[:kind]
      when "title"
        [
          text_block(segment[:title], "title", 0.088, title_color, max_lines: 3),
          rule_block(accent),
          text_block(segment[:subtitle], "body", 0.036, body_color, max_lines: 2)
        ]
      when "chapter"
        [
          text_block(segment[:title], "title", 0.062, title_color, max_lines: 2),
          rule_block(accent),
          text_block(segment[:narration], "body", 0.037, body_color, max_lines: 6, width_ratio: 0.66)
        ]
      when "ending"
        [
          text_block(segment[:text], "italic", 0.055, title_color, max_lines: 5, width_ratio: 0.7),
          rule_block(accent),
          text_block(segment[:signature], "body", 0.032, body_color, max_lines: 1)
        ]
      else
        []
      end
      layout_blocks(blocks.compact, shadow: dark)
    end

    Block = Struct.new(:lines, :font_key, :size, :color, :rule, keyword_init: true)

    def text_block(text, font_key, size_ratio, color, max_lines:, width_ratio: 0.8)
      return nil if text.blank?
      size = (big_h * size_ratio).round
      lines = TextLayout.wrap(text, max_width: big_w * width_ratio, font_size: size, max_lines:)
      return nil if lines.empty?
      Block.new(lines:, font_key:, size:, color:)
    end

    def rule_block(color)
      Block.new(lines: [], size: (big_h * 0.05).round, color:, rule: true)
    end

    def layout_blocks(blocks, shadow:)
      blocks = blocks.dup
      blocks.shift while blocks.first&.rule
      blocks.pop while blocks.last&.rule
      heights = blocks.map { |b| b.rule ? b.size : (b.lines.length * b.size * 1.42).round }
      y = ((big_h - heights.sum) / 2.0).round
      filters = []
      blocks.each_with_index do |block, i|
        if block.rule
          w = (big_w * 0.06).round
          filters << "drawbox=x=(iw-#{w})/2:y=#{y + block.size / 2}:w=#{w}:h=#{SUPERSAMPLE * 2}:color=#{block.color}@0.9:t=fill"
        else
          block.lines.each_with_index do |line, li|
            filters << drawtext(line, font_key: block.font_key, size: block.size, color: block.color,
                                x: "(w-text_w)/2", y: (y + li * block.size * 1.42).round, shadow:)
          end
        end
        y += heights[i]
      end
      filters
    end

    def caption_filters(caption, color:, boxed:, font_key: "caption")
      return [] if caption.blank?
      size = (big_h * (boxed ? 0.032 : 0.038)).round
      line = TextLayout.wrap(caption, max_width: big_w * 0.7, font_size: size, max_lines: 1).first
      return [] unless line
      y = boxed ? "h-#{(big_h * 0.11).round}" : "h-#{(big_h * 0.12).round}"
      [drawtext(line, font_key:, size:, color:, x: "(w-text_w)/2", y:, shadow: false,
                box: boxed ? "box=1:boxcolor=black@0.45:boxborderw=#{(size * 0.6).round}" : nil)]
    end

    def drawtext(text, font_key:, size:, color:, x:, y:, shadow:, box: nil)
      file = File.join(@work_dir, format("text_%04d.txt", @text_counter += 1))
      File.write(file, TextLayout.clean(text).tr("\n", " "), mode: "w", encoding: "UTF-8")
      parts = [
        "drawtext=fontfile='#{font(font_key)}'", "textfile='#{file}'", "expansion=none",
        "fontsize=#{size}", "fontcolor=#{color}", "x=#{x}", "y=#{y}"
      ]
      parts << "shadowcolor=black@0.55:shadowx=#{SUPERSAMPLE * 2}:shadowy=#{SUPERSAMPLE * 2}" if shadow
      parts << box if box
      parts.join(":")
    end

    # ---------- step 2: clips with motion ----------

    def render_clip(still, segment, index, extra:)
      out = File.join(@work_dir, format("clip_%03d.mp4", index))
      frames = ((segment[:duration] + extra) * fps).round
      z, x, y = motion_expressions(segment, frames)
      filter = "[0:v]zoompan=z='#{z}':x='#{x}':y='#{y}':d=#{frames}:s=#{width}x#{height}:fps=#{fps}," \
               "setsar=1,format=yuv420p[v]"
      Command.run!("ffmpeg", "-y", "-loglevel", "error", "-i", still, "-filter_complex", filter,
                   "-map", "[v]", "-frames:v", frames.to_s, "-r", fps.to_s,
                   "-c:v", "libx264", "-preset", "veryfast", "-crf", "18", out, timeout: 180)
      out
    end

    def motion_expressions(segment, frames)
      zmax = album? ? 1.04 : @config["max_zoom"].to_f
      center_x = "iw/2-(iw/zoom/2)"
      center_y = "ih/2-(ih/zoom/2)"
      progress = "on/#{frames}"
      return ["1+0.035*#{progress}", center_x, center_y] unless segment[:kind] == "photo"

      case album? ? "zoom_in" : segment[:motion]
      when "zoom_out" then ["#{zmax}-#{(zmax - 1).round(4)}*#{progress}", center_x, center_y]
      when "pan_right" then [zmax.to_s, "(iw-iw/zoom)*#{progress}", center_y]
      when "pan_left" then [zmax.to_s, "(iw-iw/zoom)*(1-#{progress})", center_y]
      else ["1+#{(zmax - 1).round(4)}*#{progress}", center_x, center_y]
      end
    end

    # ---------- step 3: join + music ----------

    def assemble(clips, segments, output)
      total = segments.sum { |s| s[:duration] }.round(3)
      t = transition
      style = @config["transition_style"].presence || "fade"
      fade_color = album? ? background_hex : "black"

      inputs = clips.flat_map { |c| ["-i", c] }
      video_chain = []
      if clips.length == 1
        video_chain << "[0:v]null[joined]"
      else
        offset = segments[0][:duration]
        prev = "[0:v]"
        (1...clips.length).each do |i|
          label = i == clips.length - 1 ? "[joined]" : "[x#{i}]"
          video_chain << "#{prev}[#{i}:v]xfade=transition=#{style}:duration=#{t}:offset=#{offset.round(3)}#{label}"
          prev = label
          offset += segments[i][:duration]
        end
      end
      video_chain << "[joined]fade=t=in:st=0:d=0.8:color=#{fade_color}," \
                     "fade=t=out:st=#{(total - 1.2).round(3)}:d=1.2:color=#{fade_color},format=yuv420p[v]"

      audio_index = clips.length
      if @music_path
        inputs += ["-stream_loop", "-1", "-i", @music_path]
        audio_chain = "[#{audio_index}:a]atrim=0:#{total},asetpts=PTS-STARTPTS," \
                      "loudnorm=I=-16:TP=-1.5:LRA=11,aresample=44100," \
                      "afade=t=in:st=0:d=1.5,afade=t=out:st=#{[total - 3, 0].max.round(3)}:d=3," \
                      "aformat=sample_rates=44100:channel_layouts=stereo[a]"
      else
        inputs += ["-f", "lavfi", "-t", total.to_s, "-i", "anullsrc=r=44100:cl=stereo"]
        audio_chain = "[#{audio_index}:a]anull[a]"
      end

      Command.run!("ffmpeg", "-y", "-loglevel", "error", *inputs,
                   "-filter_complex", (video_chain + [audio_chain]).join(";"),
                   "-map", "[v]", "-map", "[a]", "-t", total.to_s,
                   "-c:v", "libx264", "-preset", "veryfast", "-crf", "20", "-pix_fmt", "yuv420p",
                   "-r", fps.to_s, "-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart",
                   output, timeout: 1200)
    end

    def deep_merge(base, other)
      base.merge(other) do |_, a, b|
        a.is_a?(Hash) && b.is_a?(Hash) ? deep_merge(a, b.transform_keys(&:to_s)) : b
      end
    end
  end
end
