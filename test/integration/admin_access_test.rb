require "test_helper"

class AdminAccessTest < ActionDispatch::IntegrationTest
  setup do
    @previous = ENV.to_h.slice("ADMIN_USERNAME", "ADMIN_PASSWORD")
    ENV["ADMIN_USERNAME"] = "admin"
    ENV["ADMIN_PASSWORD"] = "bi-mat"
  end

  teardown do
    %w[ADMIN_USERNAME ADMIN_PASSWORD].each { |key| ENV[key] = @previous[key] }
  end

  test "dashboard requires basic auth when a password is set" do
    get root_path
    assert_response :unauthorized

    get root_path, headers: { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "sai") }
    assert_response :unauthorized

    get root_path, headers: { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "bi-mat") }
    assert_response :success
  end

  test "shared page and health check stay public" do
    get shared_memory_path(token: memories(:birthday).share_token)
    assert_response :success

    get rails_health_check_path
    assert_response :success
  end
end
