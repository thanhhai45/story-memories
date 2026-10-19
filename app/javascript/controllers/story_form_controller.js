import { Controller } from "@hotwired/stimulus"

// Thêm / bớt chương trong form chỉnh sửa lời dẫn và đánh số lại.
// Việc gọi AI luôn diễn ra ở server (job nền) — trình duyệt không bao giờ giữ API key.
export default class extends Controller {
  static targets = ["scenes", "template", "count"]
  static values = { max: { type: Number, default: 6 } }

  connect() {
    this.renumber()
  }

  addScene(event) {
    event.preventDefault()
    if (this.sceneElements().length >= this.maxValue) return
    this.scenesTarget.insertAdjacentHTML("beforeend", this.templateTarget.innerHTML)
    this.renumber()
    this.sceneElements().at(-1)?.querySelector("input, textarea")?.focus()
  }

  removeScene(event) {
    event.preventDefault()
    event.target.closest("[data-scene]")?.remove()
    this.renumber()
  }

  renumber() {
    const scenes = this.sceneElements()
    scenes.forEach((scene, index) => {
      const label = scene.querySelector("[data-scene-number]")
      if (label) label.textContent = index + 1
    })
    if (this.hasCountTarget) {
      this.countTarget.textContent = `${scenes.length}/${this.maxValue} chương`
    }
  }

  sceneElements() {
    return Array.from(this.scenesTarget.querySelectorAll("[data-scene]"))
  }
}
