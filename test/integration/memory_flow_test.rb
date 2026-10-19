require "test_helper"

class MemoryFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @memory = memories(:wedding)
    @previous_key = ENV.delete("ANTHROPIC_API_KEY") # không gọi AI thật trong test
  end

  teardown { ENV["ANTHROPIC_API_KEY"] = @previous_key if @previous_key }

  test "dashboard and memory pages render" do
    get root_path
    assert_response :success
    assert_select "h1", "Những khoảnh khắc đáng nhớ"

    get memory_path(@memory)
    assert_response :success
    assert_select "h1", @memory.title
  end

  test "create, update and destroy a memory" do
    assert_difference -> { Memory.count } do
      post memories_path, params: { memory: { title: "Ngày yêu nhau", occasion: "relationship", style: "romantic",
                                              start_date: "2021-02-14", story_notes: "Lần đầu gặp ở quán cà phê." } }
    end
    memory = Memory.order(:id).last
    assert_redirected_to memory_path(memory, anchor: "photos")

    patch memory_path(memory), params: { memory: { title: "Ngày yêu nhau 💕" } }
    assert_redirected_to memory_path(memory)
    assert_equal "Ngày yêu nhau 💕", memory.reload.title

    assert_difference -> { Memory.count }, -1 do
      delete memory_path(memory)
    end
    assert_redirected_to root_path
  end

  test "invalid memory re-renders the form" do
    post memories_path, params: { memory: { title: "" } }
    assert_response 422
  end

  test "upload photos via JSON (Stimulus) and via a plain form" do
    post memory_photos_path(@memory), params: { photo: { image: fixture_file_upload("photo.jpg", "image/jpeg") } },
                                      headers: { "Accept" => "application/json" }
    assert_response :created
    assert_equal 1, @memory.memory_photos.count

    post memory_photos_path(@memory), params: { photo: { images: [
      fixture_file_upload("portrait.png", "image/png"), fixture_file_upload("not_an_image.jpg", "image/jpeg")
    ] } }
    assert_redirected_to memory_path(@memory, anchor: "photos")
    assert_equal 2, @memory.memory_photos.count
    assert_match "not_an_image.jpg", flash[:alert]
  end

  test "rejected upload returns errors as JSON" do
    post memory_photos_path(@memory), params: { photo: { image: fixture_file_upload("not_an_image.jpg", "image/jpeg") } },
                                      headers: { "Accept" => "application/json" }
    assert_response 422
    assert_not response.parsed_body["ok"]
  end

  test "reorder persists positions" do
    a = attach_photo(@memory)
    b = attach_photo(@memory)
    c = attach_photo(@memory)

    patch reorder_memory_photos_path(@memory), params: { photo_ids: [ c.id, a.id, b.id ] }, as: :json
    assert_response :success
    assert_equal [ c.id, a.id, b.id ], @memory.reload.memory_photos.map(&:id)
  end

  test "reorder ignores photos from other memories" do
    mine = attach_photo(@memory)
    other = attach_photo(memories(:birthday))
    patch reorder_memory_photos_path(@memory), params: { photo_ids: [ other.id, mine.id ] }, as: :json
    assert_response :success
    assert_equal 1, other.reload.position
  end

  test "update caption, set cover, delete photo" do
    photo = attach_photo(@memory)
    patch memory_photo_path(@memory, photo), params: { memory_photo: { caption: "Đà Lạt", cover: true } }
    assert_equal "Đà Lạt", photo.reload.caption
    assert photo.cover?

    delete memory_photo_path(@memory, photo)
    assert_equal 0, @memory.memory_photos.count
  end

  test "generate a story enqueues a job, then the user can edit it" do
    attach_photo(@memory)
    assert_enqueued_with(job: GenerateStoryJob) do
      post memory_story_path(@memory)
    end
    assert_redirected_to memory_story_path(@memory)
    assert @memory.latest_story.pending?

    get memory_story_path(@memory)
    assert_response :success

    perform_enqueued_jobs
    assert @memory.latest_story.reload.completed?

    patch memory_story_path(@memory), params: { story: {
      title: "Sáu năm", subtitle: "2020 — 2026", ending: "Mãi bên nhau",
      scenes: [ { title: "Chương 1", narration: "Bắt đầu", photo_positions: "1" } ]
    } }
    assert_redirected_to memory_story_path(@memory)
    assert_equal "Sáu năm", @memory.current_story.title
  end

  test "render requires photos and story; then enqueues a render" do
    post memory_video_renders_path(@memory)
    assert_redirected_to memory_path(@memory, anchor: "video")
    assert_equal 0, @memory.video_renders.count

    attach_photo(@memory)
    assert_enqueued_with(job: RenderVideoJob) do
      post memory_video_renders_path(@memory), params: { video_render: {
        video_template_id: video_templates(:album).id, music_track: "vui_tuoi"
      } }
    end
    video_render = @memory.video_renders.last
    assert_redirected_to memory_video_render_path(@memory, video_render)
    assert_equal video_templates(:album), video_render.video_template
    assert_equal "vui_tuoi", video_render.music_track
    assert_equal "rendering", @memory.reload.status

    get memory_video_render_path(@memory, video_render)
    assert_response :success
    assert_select "[data-controller=status-poll]"
  end

  test "render ignores music tracks outside the allow-list" do
    attach_photo(@memory)
    post memory_video_renders_path(@memory), params: { video_render: { music_track: "../../secret" } }
    assert_includes MusicLibrary.keys, @memory.video_renders.last.music_track
  end

  test "sharing can be enabled, rotated and disabled" do
    post memory_sharing_path(@memory)
    token = @memory.reload.share_token
    assert @memory.share_enabled?

    get shared_memory_path(token: token)
    assert_response :success
    assert_select "a[href*=edit]", false
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]

    patch rotate_memory_sharing_path(@memory)
    get shared_memory_path(token: token)
    assert_response :not_found

    delete memory_sharing_path(@memory)
    get shared_memory_path(token: @memory.reload.share_token)
    assert_response :not_found
  end

  test "unknown share tokens are not found" do
    get "/s/#{'x' * 32}"
    assert_response :not_found
  end
end
