class Story < ApplicationRecord
  STATUSES = %w[pending generating completed failed].freeze

  belongs_to :memory, touch: true
  has_many :video_renders, dependent: :nullify

  validates :status, inclusion: { in: STATUSES }
  validate :content_must_be_valid, if: :completed?

  scope :completed, -> { where(status: "completed") }
  scope :in_progress, -> { where(status: %w[pending generating]) }

  STATUSES.each do |name|
    define_method(:"#{name}?") { status == name }
  end

  def in_progress? = pending? || generating?
  def finished? = completed? || failed?

  def title = generated_content["title"].to_s
  def subtitle = generated_content["subtitle"].to_s
  def ending = generated_content["ending"].to_s
  def scenes = Array(generated_content["scenes"])
  def source = generated_content["source"].to_s

  def ai_generated? = source == "ai"

  # Lưu chỉnh sửa của người dùng (đã chuẩn hóa) và đánh dấu đã sửa tay.
  def apply_edits(attributes, photo_count:)
    content = Stories::Content.normalize(attributes.to_h, photo_count:)
    content["source"] = source.presence || "manual"
    content["edited"] = true
    self.generated_content = content
    self.status = "completed"
    self.error_message = nil
    self.generated_at ||= Time.current
    save
  end

  private

  def content_must_be_valid
    Stories::Content.errors_for(generated_content).each { |message| errors.add(:base, message) }
  end
end
