import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "button"]

  select() {
    this.sourceTarget.select()
  }

  async copy(event) {
    event.preventDefault()
    const text = this.sourceTarget.value
    try {
      await navigator.clipboard.writeText(text)
    } catch (_) {
      this.sourceTarget.select()
      document.execCommand("copy")
    }
    const original = this.buttonTarget.textContent
    this.buttonTarget.textContent = "Đã sao chép"
    setTimeout(() => (this.buttonTarget.textContent = original), 1800)
  }
}
