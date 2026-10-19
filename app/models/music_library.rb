# Danh sách nhạc nền được phép dùng. Người dùng chỉ chọn theo key;
# đường dẫn file do hệ thống quyết định (không nhận path từ request).
#
# Các bản mặc định do dự án tự tổng hợp (script/synthesize_music.py) nên không
# vướng bản quyền. Muốn thêm nhạc: chép file .m4a/.mp3 có giấy phép hợp lệ vào
# public/music rồi khai báo thêm một dòng bên dưới.
class MusicLibrary
  Track = Data.define(:key, :name, :mood, :genre, :file, :license) do
    def mood_label = MOODS[mood]
  end

  MOODS = {
    "romantic" => "Lãng mạn", "nostalgic" => "Hoài niệm", "playful" => "Vui tươi",
    "happy" => "Hạnh phúc", "dreamy" => "Mơ màng"
  }.freeze

  OWN = "Tự tổng hợp cho dự án, dùng tự do".freeze

  # Bản đầu tiên của mỗi mood là bản mặc định cho phong cách tương ứng
  TRACKS = [
    Track.new(key: "piano_nhe_nhang", name: "Piano nhẹ nhàng", mood: "romantic", genre: "Piano",
              file: "piano_nhe_nhang.m4a", license: OWN),
    Track.new(key: "am_ap", name: "Ấm áp", mood: "nostalgic", genre: "Piano & pad",
              file: "am_ap.m4a", license: OWN),
    Track.new(key: "vui_tuoi", name: "Vui tươi", mood: "playful", genre: "Pluck",
              file: "vui_tuoi.m4a", license: OWN),
    Track.new(key: "guitar_ballad", name: "Ballad guitar", mood: "romantic", genre: "Guitar",
              file: "guitar_ballad.m4a", license: OWN),
    Track.new(key: "waltz_ngay_cuoi", name: "Waltz ngày cưới", mood: "romantic", genre: "Waltz",
              file: "waltz_ngay_cuoi.m4a", license: OWN),
    Track.new(key: "hop_nhac", name: "Hộp nhạc", mood: "dreamy", genre: "Music box",
              file: "hop_nhac.m4a", license: OWN),
    Track.new(key: "lofi_chill", name: "Lofi chill", mood: "nostalgic", genre: "Lofi",
              file: "lofi_chill.m4a", license: OWN),
    Track.new(key: "pop_soi_dong", name: "Pop sôi động", mood: "happy", genre: "Pop",
              file: "pop_soi_dong.m4a", license: OWN),
    Track.new(key: "ukulele_vui", name: "Ukulele", mood: "playful", genre: "Ukulele",
              file: "ukulele_vui.m4a", license: OWN)
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
