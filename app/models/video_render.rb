class VideoRender < ApplicationRecord
  STATUSES = %w[queued processing completed failed].freeze

  belongs_to :memory, touch: true
  belongs_to :story, optional: true
  belongs_to :video_template, optional: true

  has_one_attached :output_video

  validates :status, inclusion: { in: STATUSES }
  validates :progress, numericality: { only_integer: true, in: 0..100 }
  validates :music_track, inclusion: { in: ->(_) { MusicLibrary.keys } }, allow_blank: true

  scope :completed, -> { where(status: "completed") }
  scope :active, -> { where(status: %w[queued processing]) }
  scope :recent, -> { order(created_at: :desc, id: :desc) }

  STATUSES.each do |name|
    define_method(:"#{name}?") { status == name }
  end

  def finished? = completed? || failed?

  def status_label
    { "queued" => "Đang chờ", "processing" => "Đang dựng video",
      "completed" => "Hoàn tất", "failed" => "Lỗi" }.fetch(status)
  end

  def duration_seconds = metadata["duration"]&.to_f

  def duration_label
    return nil unless duration_seconds
    total = duration_seconds.round
    format("%d:%02d", total / 60, total % 60)
  end

  def download_filename
    base = memory.title.to_s.unicode_normalize(:nfkd).gsub(/\p{Mn}/, "").tr("đĐ", "dD")
    base = base.parameterize.presence || "ky-niem"
    "#{base}-#{id}.mp4"
  end

  def mark_processing!
    update!(status: "processing", started_at: Time.current, progress: 0, error_message: nil)
  end

  def mark_completed!(metadata:)
    update!(status: "completed", progress: 100, finished_at: Time.current, metadata:)
  end

  def mark_failed!(message)
    update!(status: "failed", finished_at: Time.current, error_message: message.to_s.truncate(500))
  end
end
