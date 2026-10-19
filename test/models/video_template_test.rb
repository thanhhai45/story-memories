require "test_helper"

class VideoTemplateTest < ActiveSupport::TestCase
  test "all default templates are valid and suggest an existing track" do
    VideoTemplate.sync_defaults!
    VideoTemplate::DEFAULTS.each do |attrs|
      template = VideoTemplate.find_by!(slug: attrs[:slug])
      assert template.valid?, "#{attrs[:slug]}: #{template.errors.full_messages.join(', ')}"
      assert_equal attrs[:configuration]["music"], template.suggested_music if attrs[:configuration]["music"]
    end
  end

  test "rejects unsupported effects" do
    template = VideoTemplate.new(name: "X", slug: "x", configuration: {
      "layout" => "cinematic", "transitions" => %w[fade boom], "motions" => %w[spin],
      "particles" => "fireworks", "grade" => "neon"
    })
    assert_not template.valid?
    assert_equal 4, template.errors[:configuration].size
  end

  test "every music track file exists" do
    MusicLibrary.all.each { |track| assert MusicLibrary.path_for(track.key), "missing #{track.file}" }
  end
end
