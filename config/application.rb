require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_view/railtie"
require "action_cable/engine"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

module AnniversaryMemories
  class Application < Rails::Application
    config.load_defaults 8.0

    # assets/tasks: chuẩn Rails. Thư mục lib còn lại được autoload.
    config.autoload_lib(ignore: %w[assets tasks])

    config.time_zone = "Asia/Ho_Chi_Minh"
    config.i18n.available_locales = %i[vi en]
    config.i18n.default_locale = :vi

    config.active_storage.variant_processor = :vips
    # Video và ảnh được phục vụ qua redirect tới URL ký số, không đoán được.
    config.active_storage.resolve_model_to_route = :rails_storage_redirect

    config.generators do |g|
      g.helper false
      g.system_tests nil
    end
  end
end
