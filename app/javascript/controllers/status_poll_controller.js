import { Controller } from "@hotwired/stimulus"

// Polling nhẹ: tải lại turbo-frame chứa trạng thái mỗi vài giây,
// tự dừng khi job đã hoàn tất hoặc lỗi (active = false).
export default class extends Controller {
  static values = {
    url: String,
    active: Boolean,
    interval: { type: Number, default: 2500 }
  }

  connect() {
    if (this.activeValue) {
      this.timer = setTimeout(() => this.refresh(), this.intervalValue)
    }
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  refresh() {
    if (document.hidden) {
      this.timer = setTimeout(() => this.refresh(), this.intervalValue)
      return
    }
    const frame = this.element.closest("turbo-frame")
    if (!frame) {
      window.Turbo.visit(window.location.href, { action: "replace" })
    } else if (frame.src) {
      frame.reload()
    } else {
      frame.src = this.urlValue || window.location.href
    }
  }
}
