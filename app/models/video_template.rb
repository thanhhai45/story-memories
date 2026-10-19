class VideoTemplate < ApplicationRecord
  DEFAULTS = [
    {
      slug: "romantic_cinematic",
      name: "Romantic Cinematic",
      description: "Khung 16:9, nền tối từ chính bức ảnh làm mờ, zoom chậm, chuyển cảnh mờ dần, chữ có chân thanh lịch.",
      position: 1,
      configuration: {
        "layout" => "cinematic", "width" => 1280, "height" => 720, "fps" => 30,
        "title_duration" => 4.5, "chapter_duration" => 4.0, "photo_duration" => 3.6,
        "ending_duration" => 5.5, "max_duration" => 95, "transition" => 0.8,
        "transition_style" => "fade", "max_zoom" => 1.12,
        "palette" => { "background" => "17131D", "text" => "FFFFFF", "muted" => "DCD3E6", "accent" => "E2C08D" }
      }
    },
    {
      slug: "photo_album",
      name: "Photo Album",
      description: "Trang album giấy, ảnh viền trắng hơi nghiêng có bóng đổ, chú thích từng ảnh, lật trang nhẹ nhàng.",
      position: 2,
      configuration: {
        "layout" => "album", "width" => 1280, "height" => 720, "fps" => 30,
        "title_duration" => 4.5, "chapter_duration" => 4.0, "photo_duration" => 3.4,
        "ending_duration" => 5.0, "max_duration" => 95, "transition" => 0.6,
        "transition_style" => "slideleft",
        "palette" => { "background" => "EEE7DC", "text" => "3A2F2C", "muted" => "6A5C57", "accent" => "B08D57" }
      }
    },
    {
      slug: "romantic_hearts",
      name: "Lãng mạn · Tim bay",
      description: "Tông hồng ấm, những trái tim nhỏ bay lên, chuyển cảnh mềm như vòng tròn mở và tan dần.",
      position: 3,
      configuration: {
        "layout" => "cinematic", "width" => 1280, "height" => 720, "fps" => 30,
        "title_duration" => 5.0, "chapter_duration" => 4.5, "photo_duration" => 3.8,
        "ending_duration" => 6.0, "max_duration" => 100, "transition" => 1.0,
        "transitions" => %w[dissolve circleopen fade smoothup], "max_zoom" => 1.14,
        "motions" => %w[zoom_in drift zoom_out pan_up],
        "grade" => "warm_rose", "particles" => "hearts", "music" => "guitar_ballad",
        "palette" => { "background" => "2A1420", "text" => "FFFFFF", "muted" => "F3D6E0", "accent" => "F2A7BC" }
      }
    },
    {
      slug: "playful_confetti",
      name: "Vui tươi · Confetti",
      description: "Trang album màu kem, confetti rơi, ảnh nảy nhẹ, chuyển cảnh trượt và xoay vui mắt.",
      position: 4,
      configuration: {
        "layout" => "album", "width" => 1280, "height" => 720, "fps" => 30,
        "title_duration" => 4.0, "chapter_duration" => 3.8, "photo_duration" => 3.0,
        "ending_duration" => 5.0, "max_duration" => 90, "transition" => 0.5,
        "transitions" => %w[slideleft circlecrop slideup radial wiperight slidedown], "max_zoom" => 1.07,
        "motions" => %w[bounce pan_right zoom_in pan_left],
        "grade" => "vibrant", "particles" => "confetti", "music" => "ukulele_vui",
        "palette" => { "background" => "FFF4D6", "text" => "3B2C4A", "muted" => "6B5A78", "accent" => "FF8A65" }
      }
    },
    {
      slug: "happy_sunshine",
      name: "Hạnh phúc · Nắng ấm",
      description: "Màu tươi sáng như nắng, đốm sáng lấp lánh trôi nhẹ, chuyển cảnh lóe trắng và lướt nhanh.",
      position: 5,
      configuration: {
        "layout" => "cinematic", "width" => 1280, "height" => 720, "fps" => 30,
        "title_duration" => 4.5, "chapter_duration" => 4.0, "photo_duration" => 3.3,
        "ending_duration" => 5.5, "max_duration" => 95, "transition" => 0.7,
        "transitions" => %w[fadewhite smoothleft zoomin diagtl smoothright], "max_zoom" => 1.12,
        "motions" => %w[zoom_in pan_right drift pan_down zoom_out],
        "grade" => "sunny", "particles" => "sparkles", "bg_brightness" => 0.14, "fade_color" => "FFFFFF", "music" => "pop_soi_dong",
        "palette" => { "background" => "3A2A12", "text" => "FFFFFF", "muted" => "FFF1CF", "accent" => "FFD27A" }
      }
    }
  ].freeze

  has_many :memories, dependent: :nullify
  has_many :video_renders, dependent: :nullify

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9_]+\z/ }
  validate :configuration_has_layout

  scope :active, -> { where(active: true).order(:position, :id) }

  def self.default
    active.first || (sync_defaults! && active.first)
  end

  def self.sync_defaults!
    DEFAULTS.each do |attrs|
      template = find_or_initialize_by(slug: attrs[:slug])
      template.assign_attributes(attrs.except(:slug))
      template.save!
    end
  end

  def layout = configuration["layout"]

  # Bản nhạc gợi ý đi kèm template (nếu có và còn trong thư viện)
  def suggested_music = configuration["music"].to_s.presence_in(MusicLibrary.keys)

  private

  def configuration_has_layout
    errors.add(:configuration, "thiếu layout") unless %w[cinematic album].include?(configuration["layout"])
    unknown = Array(configuration["transitions"]).map(&:to_s) - Videos::Renderer::TRANSITIONS
    errors.add(:configuration, "chuyển cảnh không hỗ trợ: #{unknown.join(', ')}") if unknown.any?
    unknown = Array(configuration["motions"]).map(&:to_s) - Videos::TimelineBuilder::ALL_MOTIONS
    errors.add(:configuration, "chuyển động không hỗ trợ: #{unknown.join(', ')}") if unknown.any?
    if configuration["particles"].present? && !Videos::Effects::PARTICLES.include?(configuration["particles"])
      errors.add(:configuration, "hiệu ứng hạt không hỗ trợ")
    end
    if configuration["grade"].present? && !Videos::Effects::GRADES.key?(configuration["grade"])
      errors.add(:configuration, "kiểu chỉnh màu không hỗ trợ")
    end
  end
end
