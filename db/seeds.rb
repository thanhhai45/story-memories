# Idempotent: chạy lại bao nhiêu lần cũng được.
VideoTemplate.sync_defaults!
puts "Video templates: #{VideoTemplate.pluck(:slug).join(', ')}"
