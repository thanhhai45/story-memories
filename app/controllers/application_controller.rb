class ApplicationController < ActionController::Base
  helper_method :ai_configured?

  private

  def ai_configured?
    ENV["ANTHROPIC_API_KEY"].present?
  end

  def set_memory
    @memory = Memory.find(params[:memory_id] || params[:id])
  end

  def too_many_requests(message = "Bạn thao tác quá nhanh. Vui lòng đợi một chút rồi thử lại.")
    respond_to do |format|
      format.html { redirect_back fallback_location: root_path, alert: message }
      format.json { render json: { ok: false, errors: [ message ] }, status: :too_many_requests }
    end
  end
end
