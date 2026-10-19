module Videos
  # Hiệu ứng trang trí phủ lên toàn bộ video: chỉnh màu và các hạt bay
  # (tim, confetti, đốm sáng). Template chỉ chọn theo tên trong danh sách cố định;
  # mọi biểu thức FFmpeg đều do code sinh ra nên không thể chèn filter lạ.
  class Effects
    GRADES = {
      "warm_rose" => "colorbalance=rs=0.05:gs=-0.01:bs=0.01:rm=0.04:bm=-0.02,eq=saturation=1.06:brightness=0.01",
      "vibrant" => "eq=saturation=1.2:contrast=1.04:brightness=0.015",
      "sunny" => "colorbalance=rs=0.04:gs=0.02:bs=-0.05:rm=0.03:bm=-0.03,eq=saturation=1.15:brightness=0.03"
    }.freeze

    PARTICLES = %w[hearts confetti sparkles].freeze

    HEART_COLORS = %w[FF6F9C E84A6F FFC2D4].freeze
    CONFETTI_COLORS = %w[FF6B6B FFD93D 6BCB77 4D96FF C77DFF FF9F45].freeze
    SPARKLE_COLORS = %w[FFF3C4 FFE08A FFFFFF].freeze

    Sprite = Struct.new(:path, :count, keyword_init: true)

    def initialize(config:, width:, height:, work_dir:, seed: 1)
      @particles = config["particles"].to_s.presence_in(PARTICLES)
      @grade = GRADES[config["grade"].to_s]
      @width = width
      @height = height
      @work_dir = work_dir
      @rng = Random.new(seed)
    end

    def grade_filter = @grade

    def particles? = @particles.present?

    # Tạo ảnh PNG cho từng loại hạt. Trả về mảng Sprite (mỗi sprite là một input -loop 1).
    def build_sprites!
      return [] unless particles?
      case @particles
      when "hearts"
        HEART_COLORS.each_with_index.map { |hex, i| Sprite.new(path: heart_sprite(hex, i), count: 4) }
      when "confetti"
        CONFETTI_COLORS.each_with_index.map { |hex, i| Sprite.new(path: confetti_sprite(hex, i), count: 3) }
      when "sparkles"
        SPARKLE_COLORS.each_with_index.map { |hex, i| Sprite.new(path: glow_sprite(hex, i), count: 6) }
      end
    end

    # Phủ hạt lên nhãn `source`. first_input là chỉ số input của sprite đầu tiên.
    # Trả về [mảng filter, nhãn đầu ra].
    def overlay_chain(source, sprites, first_input)
      chain = []
      current = source
      n = 0
      sprites.each_with_index do |sprite, s|
        labels = Array.new(sprite.count) { |k| "[p#{s}_#{k}]" }
        chain << "[#{first_input + s}:v]split=#{sprite.count}#{labels.join}"
        labels.each do |label|
          out = "[ov#{n += 1}]"
          x, y = motion
          chain << "#{current}#{label}overlay=x='#{x}':y='#{y}':format=auto#{out}"
          current = out
        end
      end
      [chain, current]
    end

    private

    # Vị trí theo thời gian t. Hạt quay vòng nên dùng được cho video dài bao nhiêu cũng được.
    def motion
      x0 = @rng.rand(0.03..0.95).round(3)
      sway = (@width * @rng.rand(0.015..0.04)).round(1)
      freq = @rng.rand(0.5..1.3).round(3)
      phase = @rng.rand(0.0..6.28).round(3)
      offset = (@height * @rng.rand(0.0..1.6)).round(1)
      x = "W*#{x0}+#{sway}*sin(t*#{freq}+#{phase})"
      case @particles
      when "confetti"
        speed = (@height * @rng.rand(0.12..0.22)).round(1)
        [x, "mod(t*#{speed}+#{offset},H+h)-h"]
      when "sparkles"
        speed = (@height * @rng.rand(0.03..0.07)).round(1)
        [x, "H-mod(t*#{speed}+#{offset},H+h)"]
      else
        speed = (@height * @rng.rand(0.07..0.13)).round(1)
        [x, "H-mod(t*#{speed}+#{offset},H+h)"]
      end
    end

    def sprite_path(name, i) = File.join(@work_dir, "sprite_#{name}_#{i}.png")

    # Đường cong trái tim (x²+y²−1)³ − x²y³ ≤ 0, vẽ ở 256px rồi thu nhỏ cho mượt viền.
    def heart_sprite(hex, i)
      size = (@height * [0.05, 0.035, 0.028][i % 3]).round.clamp(8, 200)
      u = "((X/W-0.5)*2.8)"
      v = "((0.45-Y/H)*2.8)"
      alpha = "170*lte(pow(pow(#{u},2)+pow(#{v},2)-1,3)-pow(#{u},2)*pow(#{v},3),0)"
      draw(sprite_path("heart", i),
           "color=c=0x#{hex}:s=256x256:d=1,format=rgba," \
           "geq=r='r(X,Y)':g='g(X,Y)':b='b(X,Y)':a='#{alpha}',scale=#{size}:#{size}")
    end

    def confetti_sprite(hex, i)
      w = (@height * 0.014).round.clamp(3, 60)
      h = (@height * 0.026).round.clamp(5, 100)
      angle = ((i * 37 % 90) - 45) * Math::PI / 180
      draw(sprite_path("confetti", i),
           "color=c=0x#{hex}:s=#{w}x#{h}:d=1,format=rgba," \
           "rotate=#{angle.round(4)}:c=none:ow=rotw(#{angle.round(4)}):oh=roth(#{angle.round(4)})")
    end

    # Đốm sáng mềm: độ trong suốt giảm dần từ tâm ra viền.
    def glow_sprite(hex, i)
      size = (@height * [0.11, 0.07, 0.045][i % 3]).round.clamp(6, 240)
      alpha = "190*pow(max(0,1-hypot(X-W/2,Y-H/2)/(W/2)),1.6)"
      draw(sprite_path("glow", i),
           "color=c=0x#{hex}:s=128x128:d=1,format=rgba," \
           "geq=r='r(X,Y)':g='g(X,Y)':b='b(X,Y)':a='#{alpha}',scale=#{size}:#{size}")
    end

    def draw(out, graph)
      Command.run!("ffmpeg", "-y", "-loglevel", "error", "-f", "lavfi", "-i", graph,
                   "-frames:v", "1", "-update", "1", out, timeout: 30)
      out
    end
  end
end
