module ApplicationHelper
  def page_title(*parts)
    content_for(:title, parts.compact_blank.join(" · "))
  end

  def memory_status_badge(memory)
    label, tone = {
      "draft" => [ "Bản nháp", "bg-mist text-ink/70" ],
      "rendering" => [ "Đang dựng video", "bg-gilt/15 text-gilt-deep" ],
      "ready" => [ "Đã có video", "bg-plum/10 text-plum" ]
    }.fetch(memory.status, [ memory.status, "bg-mist text-ink/70" ])
    tag.span(label, class: "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium #{tone}")
  end

  def render_status_badge(video_render)
    tone = {
      "queued" => "bg-mist text-ink/70", "processing" => "bg-gilt/15 text-gilt-deep",
      "completed" => "bg-plum/10 text-plum", "failed" => "bg-rose/10 text-rose"
    }.fetch(video_render.status)
    tag.span(video_render.status_label, class: "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium #{tone}")
  end

  def human_size(bytes)
    number_to_human_size(bytes, precision: 2, locale: :vi)
  end

  def date_range(memory)
    dates = [ memory.start_date, memory.end_date ].compact
    return nil if dates.empty?
    dates.map { |date| l(date, format: :long) }.join(" – ")
  end

  # Link file có hạn dùng (mặc định 1 giờ) — dùng cho trang công khai để
  # việc tắt chia sẻ thực sự thu hồi quyền xem trong thời gian ngắn.
  def expiring_blob_path(attachment, disposition: :inline, expires_in: 1.hour)
    blob = attachment.blob
    rails_service_blob_path(blob.signed_id(expires_in:), blob.filename, disposition:)
  end

  def music_url(track)
    "/music/#{track.file}"
  end
end
