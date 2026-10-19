Rails.application.configure do
  # URL tạm của file (sau khi redirect) chỉ sống 1 giờ — đủ để xem/tua video.
  config.active_storage.service_urls_expire_in = 1.hour
end
