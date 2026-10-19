# Danh sách nhạc nền được phép dùng. Người dùng chỉ chọn theo key;
# đường dẫn file do hệ thống quyết định (không nhận path từ request).
#
# 3 bản mặc định do dự án tự tổng hợp (script/synthesize_music.py) nên không
# vướng bản quyền. Muốn thêm nhạc: chép file .m4a/.mp3 có giấy phép hợp lệ vào
# public/music rồi khai báo thêm một dòng bên dưới.
class MusicLibrary
  Track = Data.define(:key, :name, :mood, :file, :license)

  TRACKS = [
    Track.new(key: "piano_nhe_nhang", name: "Piano nhẹ nhàng", mood: "romantic",
              file: "piano_nhe_nhang.m4a", license: "Tự tổng hợp cho dự án, dùng tự do"),
    Track.new(key: "am_ap", name: "Ấm áp", mood: "nostalgic",
              file: "am_ap.m4a", license: "Tự tổng hợp cho dự án, dùng tự do"),
    Track.new(key: "vui_tuoi", name: "Vui tươi", mood: "playful",
              file: "vui_tuoi.m4a", license: "Tự tổng hợp cho dự án, dùng tự do")
  ].freeze

  DIRECTORY = Rails.root.join("public/music")

  class << self
    def all = TRACKS
    def keys = TRACKS.map(&:key)
    def find(key) = TRACKS.find { |track| track.key == key.to_s }

    def path_for(key)
      track = find(key) or return nil
      path = DIRECTORY.join(track.file)
      path.file? ? path : nil
    end

    def default_for(style)
      (TRACKS.find { |track| track.mood == style.to_s } || TRACKS.first).key
    end

    def options_for_select = TRACKS.map { |track| [ track.name, track.key ] }
  end
end
