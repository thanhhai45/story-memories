class Memory < ApplicationRecord
  OCCASIONS = {
    "anniversary" => "Kỷ niệm ngày cưới",
    "relationship" => "Ngày yêu nhau",
    "birthday" => "Sinh nhật",
    "family" => "Kỷ niệm gia đình",
    "custom" => "Một cột mốc khác"
  }.freeze

  STYLES = {
    "romantic" => "Lãng mạn, ấm áp",
    "playful" => "Vui tươi",
    "nostalgic" => "Hoài niệm"
  }.freeze

  STATUSES = %w[draft rendering ready].freeze
  MAX_PHOTOS = 30
  MIN_PHOTOS_FOR_VIDEO = 1

  belongs_to :video_template, optional: true
  has_many :memory_photos, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :memory
  has_many :stories, dependent: :destroy
  has_many :video_renders, dependent: :destroy

  normalizes :title, :person_names, with: ->(value) { value.to_s.squish.presence }
  normalizes :story_notes, with: ->(value) { value.to_s.strip.presence }

  validates :title, presence: true, length: { maximum: 120 }
  validates :occasion, inclusion: { in: OCCASIONS.keys }
  validates :style, inclusion: { in: STYLES.keys }
  validates :status, inclusion: { in: STATUSES }
  validates :person_names, length: { maximum: 200 }
  validates :story_notes, length: { maximum: 3000 }
  validates :music_track, inclusion: { in: ->(_) { MusicLibrary.keys } }, allow_blank: true
  validates :share_token, uniqueness: true, allow_nil: true
  validate :end_date_not_before_start_date

  before_validation :assign_defaults, on: :create

  scope :recent, -> { order(updated_at: :desc) }

  def self.find_shared(token)
    return nil if token.blank? || token.length > 64
    find_by(share_token: token.to_s, share_enabled: true)
  end

  def self.generate_share_token
    loop do
      token = SecureRandom.urlsafe_base64(24)
      break token unless exists?(share_token: token)
    end
  end

  # ----- photos -----

  def cover_photo
    memory_photos.detect(&:cover?) || memory_photos.first
  end

  def photos_remaining
    [ MAX_PHOTOS - memory_photos.size, 0 ].max
  end

  # ----- story / renders -----

  def latest_story
    stories.order(created_at: :desc, id: :desc).first
  end

  def current_story
    stories.completed.order(generated_at: :desc, id: :desc).first
  end

  def latest_render
    video_renders.order(created_at: :desc, id: :desc).first
  end

  def latest_completed_render
    video_renders.completed.order(finished_at: :desc, id: :desc).first
  end

  def ready_for_render?
    memory_photos.size >= MIN_PHOTOS_FOR_VIDEO && current_story.present?
  end

  def refresh_status!
    new_status =
      if video_renders.active.exists? then "rendering"
      elsif video_renders.completed.exists? then "ready"
      else "draft"
      end
    update_column(:status, new_status) if status != new_status
  end

  # ----- sharing -----

  def enable_sharing!
    update!(share_enabled: true, share_token: share_token.presence || self.class.generate_share_token)
  end

  def disable_sharing!
    update!(share_enabled: false)
  end

  def regenerate_share_token!
    update!(share_token: self.class.generate_share_token)
  end

  def shared?
    share_enabled? && share_token.present?
  end

  # ----- presentation -----

  def occasion_label = OCCASIONS[occasion]
  def style_label = STYLES[style]

  def period_label
    years = [ start_date&.year, end_date&.year ].compact.uniq
    years.join(" — ").presence
  end

  def years_together
    return nil unless start_date
    ((end_date || Date.current).year - start_date.year)
  end

  def effective_template
    video_template&.active? ? video_template : VideoTemplate.default
  end

  def effective_music_track
    music_track.presence || MusicLibrary.default_for(style)
  end

  private

  def assign_defaults
    self.occasion ||= "anniversary"
    self.style ||= "romantic"
    self.status ||= "draft"
    self.video_template ||= VideoTemplate.default
    self.music_track = MusicLibrary.default_for(style) if music_track.blank?
  end

  def end_date_not_before_start_date
    return unless start_date && end_date && end_date < start_date
    errors.add(:end_date, :before_start_date, message: "không được trước ngày bắt đầu")
  end
end
