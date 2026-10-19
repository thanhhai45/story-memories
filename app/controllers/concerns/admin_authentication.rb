# Lớp bảo vệ tối thiểu khi chưa có hệ thống đăng nhập:
# HTTP Basic Auth cho toàn bộ trang quản trị nếu đặt ADMIN_PASSWORD.
# Trang chia sẻ /s/:token được mở công khai qua `allow_public_access`.
module AdminAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :require_admin
  end

  class_methods do
    def allow_public_access(**options)
      skip_before_action :require_admin, **options
    end
  end

  private

  def require_admin
    password = ENV["ADMIN_PASSWORD"].to_s
    if password.empty?
      return unless Rails.env.production? && ENV["ALLOW_OPEN_ADMIN"] != "true"
      render plain: "Chưa cấu hình ADMIN_PASSWORD cho trang quản trị.", status: :service_unavailable
      return
    end

    username = ENV["ADMIN_USERNAME"].presence || "admin"
    authenticate_or_request_with_http_basic("Anniversary Memories") do |given_user, given_password|
      ActiveSupport::SecurityUtils.secure_compare(given_user.to_s, username) &
        ActiveSupport::SecurityUtils.secure_compare(given_password.to_s, password)
    end
  end
end
