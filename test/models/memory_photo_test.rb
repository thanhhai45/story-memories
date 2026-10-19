require "test_helper"

class MemoryPhotoTest < ActiveSupport::TestCase
  setup { @memory = memories(:wedding) }

  test "accepts jpeg and png and assigns increasing positions" do
    first = attach_photo(@memory)
    second = attach_photo(@memory, "portrait.png", "image/png")
    assert_equal 1, first.position
    assert_equal 2, second.position
  end

  test "rejects files that are not really images, whatever the client claims" do
    photo = MemoryPhoto.new(memory_id: @memory.id)
    photo.image.attach(io: file_fixture("not_an_image.jpg").open, filename: "not_an_image.jpg", content_type: "image/jpeg")
    assert_not photo.valid?
    assert photo.errors.key?(:image)
  end

  test "rejects files above the size limit" do
    photo = MemoryPhoto.new(memory_id: @memory.id)
    photo.image.attach(io: file_fixture("photo.jpg").open, filename: "photo.jpg", content_type: "image/jpeg")
    photo.image.blob.byte_size = MemoryPhoto::MAX_BYTES + 1
    assert_not photo.valid?
    assert photo.errors.key?(:image)
  end

  test "enforces the per-memory photo limit" do
    now = Time.current
    rows = Array.new(Memory::MAX_PHOTOS) { |i| { memory_id: @memory.id, position: i + 1, created_at: now, updated_at: now } }
    MemoryPhoto.insert_all!(rows)

    photo = MemoryPhoto.new(memory_id: @memory.id)
    photo.image.attach(io: file_fixture("photo.jpg").open, filename: "photo.jpg", content_type: "image/jpeg")
    assert_not photo.valid?
    assert_includes photo.errors[:base].join, Memory::MAX_PHOTOS.to_s
  end

  test "only one cover photo per memory" do
    first = attach_photo(@memory, cover: true)
    second = attach_photo(@memory)
    second.update!(cover: true)
    assert_not first.reload.cover?
    assert_equal second, @memory.reload.cover_photo
  end
end
