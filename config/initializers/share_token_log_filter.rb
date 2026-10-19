# Dòng log "Started GET /s/<token>" sẽ in thành "/s/[FILTERED]" để link chia sẻ
# không nằm trong log ứng dụng.
module ShareTokenLogFilter
  SHARE_PATH = %r{\A/s/[^/?]+}

  def filtered_path
    super.sub(SHARE_PATH, "/s/[FILTERED]")
  end
end

ActiveSupport.on_load(:action_dispatch_request) do
  prepend ShareTokenLogFilter
end
