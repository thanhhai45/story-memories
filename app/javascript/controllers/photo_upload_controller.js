import { Controller } from "@hotwired/stimulus"
import { csrfToken } from "controllers/csrf"

// Chọn / kéo-thả ảnh, xem trước, bỏ bớt, rồi tải lên lần lượt từng ảnh
// (mỗi request một file để không vượt giới hạn dung lượng request).
// Đây chỉ là kiểm tra sớm cho trải nghiệm tốt hơn — server vẫn validate lại.
export default class extends Controller {
  static targets = ["input", "dropzone", "queue", "submit", "status", "fallback"]
  static values = {
    url: String,
    remaining: Number,
    maxBytes: Number,
    types: { type: Array, default: ["image/jpeg", "image/png", "image/webp"] }
  }

  connect() {
    this.items = []
    this.fallbackTargets.forEach((el) => el.hidden = true)
    this.render()
  }

  disconnect() {
    this.items.forEach((item) => URL.revokeObjectURL(item.url))
  }

  pick(event) {
    event.preventDefault()
    this.inputTarget.click()
  }

  choose() {
    this.add(Array.from(this.inputTarget.files))
    this.inputTarget.value = ""
  }

  dragover(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.add("is-dragging")
  }

  dragleave() {
    this.dropzoneTarget.classList.remove("is-dragging")
  }

  drop(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.remove("is-dragging")
    this.add(Array.from(event.dataTransfer.files))
  }

  add(files) {
    const problems = []
    for (const file of files) {
      if (!this.typesValue.includes(file.type)) {
        problems.push(`${file.name}: chỉ nhận ảnh JPEG, PNG hoặc WebP`)
        continue
      }
      if (file.size > this.maxBytesValue) {
        problems.push(`${file.name}: lớn hơn ${this.formatSize(this.maxBytesValue)}`)
        continue
      }
      if (this.pendingItems().length >= this.remainingValue) {
        problems.push(`Chỉ còn chỗ cho ${this.remainingValue} ảnh nữa`)
        break
      }
      this.items.push({ file, url: URL.createObjectURL(file), state: "pending", error: null })
    }
    this.render(problems)
  }

  remove(event) {
    const index = Number(event.params.index)
    const [item] = this.items.splice(index, 1)
    if (item) URL.revokeObjectURL(item.url)
    this.render()
  }

  async upload(event) {
    event.preventDefault()
    if (this.uploading) return
    this.uploading = true
    this.render()

    let failed = 0
    for (const item of this.items) {
      if (item.state === "done") continue
      item.state = "uploading"
      this.render()
      try {
        const body = new FormData()
        body.append("photo[image]", item.file)
        const response = await fetch(this.urlValue, {
          method: "POST",
          body,
          credentials: "same-origin",
          headers: { "X-CSRF-Token": csrfToken(), "Accept": "application/json" }
        })
        if (response.ok) {
          item.state = "done"
        } else {
          const data = await response.json().catch(() => ({}))
          item.state = "error"
          item.error = (data.errors || ["Tải lên không thành công"]).join(", ")
          failed++
        }
      } catch (_) {
        item.state = "error"
        item.error = "Mất kết nối, hãy thử lại"
        failed++
      }
      this.render()
    }

    this.uploading = false
    if (failed === 0) {
      window.Turbo.visit(window.location.pathname + "#photos", { action: "replace" })
    } else {
      this.items = this.items.filter((item) => item.state !== "done")
      this.render([`${failed} ảnh chưa tải lên được. Bạn có thể bỏ ảnh lỗi hoặc thử lại.`])
    }
  }

  pendingItems() {
    return this.items.filter((item) => item.state !== "done")
  }

  render(problems = []) {
    const queue = this.queueTarget
    queue.replaceChildren()

    this.items.forEach((item, index) => {
      const figure = document.createElement("figure")
      figure.className = "print relative w-28 shrink-0"

      const img = document.createElement("img")
      img.src = item.url
      img.alt = ""
      img.className = "aspect-square w-full object-cover"
      figure.append(img)

      const caption = document.createElement("figcaption")
      caption.className = "mt-1.5 truncate text-[11px] text-ink/60"
      caption.textContent = `${item.file.name} · ${this.formatSize(item.file.size)}`
      figure.append(caption)

      const state = document.createElement("p")
      state.className = "text-[11px] " + (item.state === "error" ? "text-rose" : "text-ink/50")
      state.textContent = { pending: "Chờ tải lên", uploading: "Đang tải…", done: "Đã tải lên", error: item.error }[item.state]
      figure.append(state)

      if (item.state === "pending" || item.state === "error") {
        const button = document.createElement("button")
        button.type = "button"
        button.className = "absolute -right-2 -top-2 flex h-6 w-6 items-center justify-center rounded-full bg-ink text-xs text-white"
        button.setAttribute("aria-label", `Bỏ ${item.file.name}`)
        button.textContent = "×"
        button.dataset.action = "photo-upload#remove"
        button.dataset.photoUploadIndexParam = index
        button.disabled = this.uploading
        figure.append(button)
      }
      queue.append(figure)
    })

    const pending = this.pendingItems().length
    this.submitTarget.hidden = pending === 0
    this.submitTarget.disabled = this.uploading || pending === 0
    this.submitTarget.textContent = this.uploading ? "Đang tải lên…" : `Tải lên ${pending} ảnh`
    this.statusTarget.textContent = problems.join(" · ")
  }

  formatSize(bytes) {
    if (bytes >= 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)} MB`
    return `${Math.max(1, Math.round(bytes / 1024))} KB`
  }
}
