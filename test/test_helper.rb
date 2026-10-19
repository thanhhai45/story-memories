ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Test dựng video dùng FFmpeg (nặng CPU) nên chạy tuần tự
    parallelize(workers: 1)

    fixtures :all

    def attach_photo(memory, file = "photo.jpg", content_type = "image/jpeg", **attrs)
      photo = MemoryPhoto.new(memory_id: memory.id, **attrs)
      photo.image.attach(io: file_fixture(file).open, filename: file, content_type:)
      photo.save!
      photo
    end

    def ffmpeg_available?
      system("ffmpeg", "-version", out: File::NULL, err: File::NULL)
    end
  end
end
