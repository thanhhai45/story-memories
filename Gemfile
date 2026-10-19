source "https://rubygems.org"

# Rails 8 full-stack: MVC + Hotwire (Turbo, Stimulus) + importmap, không cần Node.js
gem "rails", "~> 8.0.2"
gem "propshaft"
gem "pg", "~> 1.5"
gem "puma", ">= 6.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "tailwindcss-rails", "~> 4.0"

# Background jobs chạy trên PostgreSQL, không cần Redis
gem "solid_queue", "~> 1.1"

# Ảnh: thumbnail + chuẩn hóa (xoay theo EXIF) trước khi đưa vào FFmpeg
gem "image_processing", "~> 1.14"

# Bản dịch tiếng Việt cho thông báo lỗi, ngày tháng
gem "rails-i18n", "~> 8.0"

# Lưu ảnh/video trên S3 hoặc dịch vụ tương thích khi cần (tùy chọn)
gem "aws-sdk-s3", require: false

gem "bootsnap", require: false
gem "thruster", require: false
gem "kamal", require: false
gem "tzinfo-data", platforms: %i[ windows jruby ]

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "brakeman", require: false
end
