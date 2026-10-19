class MemoryPhoto < ApplicationRecord
  ALLOWED_CONTENT_TYPES = %w[image/jpeg image/png image/webp].freeze
  MAX_BYTES = 15.megabytes

  belongs_to :memory, inverse_of: :memory_photos, touch: true

  has_one_attached :image do |attachable|
    attachable.variant :thumb, resize_to_fill: [ 480, 480 ], format: :webp, saver: { quality: 80 }
    # Ảnh chuẩn hóa để dựng video: xoay đúng chiều theo EXIF, giới hạn kích thước, JPEG.
    attachable.variant :render, resize_to_limit: [ 2560, 2560 ], format: :jpeg, saver: { quality: 90 }
  end

  validates :caption, length: { maximum: 140 }
  validates :alt_text, length: { maximum: 200 }
  validate :image_must_be_valid
  validate :within_photo_limit, on: :create

  before_create :assign_position
  after_save :unset_other_covers, if: -> { saved_change_to_cover? && cover? }

  normalizes :caption, :alt_text, with: ->(value) { value.to_s.squish.presence }

  private

  def assign_position
    self.position = (MemoryPhoto.where(memory_id: memory_id).maximum(:position) || 0) + 1 if position.to_i.zero?
  end

  def unset_other_covers
    memory.memory_photos.where.not(id: id).where(cover: true).update_all(cover: false)
  end

  # Không tin MIME type trình duyệt gửi lên: kiểm tra content type do Active Storage
  # nhận diện (Marcel) VÀ chữ ký nhị phân ở đầu file.
  def image_must_be_valid
    unless image.attached?
      errors.add(:image, :blank)
      return
    end

    blob = image.blob
    unless ALLOWED_CONTENT_TYPES.include?(blob.content_type)
      errors.add(:image, :invalid_type, message: "phải là ảnh JPEG, PNG hoặc WebP")
    end
    unless signature_valid?
      errors.add(:image, :invalid_signature, message: "không phải file ảnh hợp lệ")
    end
    if blob.byte_size > MAX_BYTES
      errors.add(:image, :too_large, message: "vượt quá #{MAX_BYTES / 1.megabyte} MB")
    end
  end

  def within_photo_limit
    return unless memory
    if MemoryPhoto.where(memory_id: memory.id).count >= Memory::MAX_PHOTOS
      errors.add(:base, "Mỗi kỷ niệm chỉ có tối đa #{Memory::MAX_PHOTOS} ảnh")
    end
  end

  JPEG_MAGIC = "\xFF\xD8\xFF".b.freeze
  PNG_MAGIC = "\x89PNG\r\n\x1A\n".b.freeze

  # Chỉ kiểm tra được khi file vừa được gán trong request này (chưa lưu).
  def signature_valid?
    change = attachment_changes["image"]
    return true unless change

    attachable = change.attachable
    io = attachable.is_a?(Hash) ? attachable[:io] : attachable
    return true unless io.respond_to?(:read) && io.respond_to?(:rewind)

    header = io.read(12).to_s.b
    io.rewind
    header.start_with?(JPEG_MAGIC) || header.start_with?(PNG_MAGIC) ||
      (header[0, 4] == "RIFF" && header[8, 4] == "WEBP")
  end
end
