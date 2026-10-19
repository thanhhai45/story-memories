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

  private

  def configuration_has_layout
    errors.add(:configuration, "thiếu layout") unless %w[cinematic album].include?(configuration["layout"])
  end
end
