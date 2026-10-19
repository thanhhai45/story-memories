class MemoryPhotosController < ApplicationController
  before_action :set_memory
  before_action :set_photo, only: %i[update destroy]

  rate_limit to: 120, within: 10.minutes, only: :create, with: -> { too_many_requests }

  # Nhận một file (photo[image], Stimulus tải từng ảnh) hoặc nhiều file
  # (photo[images][], form thường khi không có JavaScript).
  def create
    uploads = [ *params.dig(:photo, :images), params.dig(:photo, :image) ]
      .select { |file| file.is_a?(ActionDispatch::Http::UploadedFile) }

    created = []
    errors = []
    if uploads.empty?
      errors << "Chưa chọn ảnh nào."
    else
      uploads.each do |file|
        if file.size > MemoryPhoto::MAX_BYTES
          errors << "#{file.original_filename}: vượt quá #{MemoryPhoto::MAX_BYTES / 1.megabyte} MB"
          next
        end
        photo = MemoryPhoto.new(memory_id: @memory.id, image: file)
        if photo.save
          created << photo
        else
          errors << "#{file.original_filename}: #{photo.errors.full_messages.to_sentence}"
        end
      end
    end

    respond_to do |format|
      format.html do
        flash[:alert] = errors.join(" · ") if errors.any?
        flash[:notice] = "Đã thêm #{created.size} ảnh." if created.any?
        redirect_to memory_path(@memory, anchor: "photos"), status: :see_other
      end
      format.json do
        if errors.empty?
          render json: { ok: true, ids: created.map(&:id) }, status: :created
        else
          render json: { ok: false, ids: created.map(&:id), errors: }, status: 422
        end
      end
    end
  end

  def update
    if @photo.update(photo_params)
      redirect_to memory_path(@memory, anchor: "photo-#{@photo.id}"), status: :see_other, notice: "Đã cập nhật ảnh."
    else
      redirect_to memory_path(@memory, anchor: "photos"), status: :see_other,
                  alert: @photo.errors.full_messages.to_sentence
    end
  end

  def destroy
    @photo.destroy!
    redirect_to memory_path(@memory, anchor: "photos"), status: :see_other, notice: "Đã xóa ảnh."
  end

  # PATCH { photo_ids: [3, 1, 2] } — lưu thứ tự mới vào cột position.
  def reorder
    requested = Array(params[:photo_ids]).map(&:to_i)
    photos = @memory.memory_photos.to_a
    by_id = photos.index_by(&:id)
    ordered = requested.filter_map { |id| by_id.delete(id) } + by_id.values

    MemoryPhoto.transaction do
      ordered.each_with_index do |photo, index|
        photo.update_column(:position, index + 1) if photo.position != index + 1
      end
      @memory.touch
    end

    respond_to do |format|
      format.json { render json: { ok: true, order: ordered.map(&:id) } }
      format.html { redirect_to memory_path(@memory, anchor: "photos"), status: :see_other }
    end
  end

  private

  def set_photo
    @photo = @memory.memory_photos.find(params[:id])
  end

  def photo_params
    params.require(:memory_photo).permit(:caption, :taken_at, :alt_text, :cover)
  end
end
