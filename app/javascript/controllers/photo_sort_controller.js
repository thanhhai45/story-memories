import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"
import { csrfToken } from "controllers/csrf"

// Kéo-thả để sắp xếp ảnh. Thứ tự được lưu ngay vào server (cột position),
// không chỉ thay đổi trên giao diện.
export default class extends Controller {
  static targets = ["list", "status"]
  static values = { url: String }

  connect() {
    this.sortable = Sortable.create(this.listTarget, {
      animation: 160,
      handle: "[data-sort-handle]",
      ghostClass: "opacity-40",
      onEnd: (event) => {
        if (event.oldIndex !== event.newIndex) this.save()
      }
    })
  }

  disconnect() {
    this.sortable?.destroy()
  }

  async save() {
    const ids = Array.from(this.listTarget.children)
      .map((el) => el.dataset.photoId)
      .filter(Boolean)
    this.renumber()
    this.setStatus("Đang lưu thứ tự…")

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        credentials: "same-origin",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": csrfToken()
        },
        body: JSON.stringify({ photo_ids: ids })
      })
      this.setStatus(response.ok ? "Đã lưu thứ tự mới" : "Chưa lưu được thứ tự. Hãy tải lại trang và thử lại.")
    } catch (_) {
      this.setStatus("Mất kết nối. Thứ tự chưa được lưu.")
    }
  }

  renumber() {
    this.listTarget.querySelectorAll("[data-position-label]").forEach((el, index) => {
      el.textContent = index + 1
    })
  }

  setStatus(message) {
    if (this.hasStatusTarget) this.statusTarget.textContent = message
  }
}
