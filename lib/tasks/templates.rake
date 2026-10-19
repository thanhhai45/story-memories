namespace :templates do
  desc "Đồng bộ cấu hình template video mặc định (romantic_cinematic, photo_album)"
  task sync: :environment do
    VideoTemplate.sync_defaults!
    puts VideoTemplate.order(:position).map { |t| "#{t.slug}: #{t.name}" }
  end
end
