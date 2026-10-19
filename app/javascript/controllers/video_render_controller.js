import { Controller } from "@hotwired/stimulus"

// Form "Tạo video": làm nổi lựa chọn template/nhạc và chỉ cho phát
// một bản nhạc nghe thử tại một thời điểm.
export default class extends Controller {
  static targets = ["option", "audio"]

  connect() {
    this.highlight()
  }

  // Chọn template thì tự chọn luôn bản nhạc gợi ý đi kèm (người dùng vẫn đổi được)
  chooseTemplate(event) {
    const key = event.target.dataset.music
    const music = key && this.element.querySelector(`input[name="video_render[music_track]"][value="${CSS.escape(key)}"]`)
    if (music) music.checked = true
    this.highlight()
  }

  highlight() {
    this.optionTargets.forEach((label) => {
      const input = label.querySelector("input[type=radio]")
      label.classList.toggle("border-plum", input?.checked)
      label.classList.toggle("ring-2", input?.checked)
      label.classList.toggle("ring-plum/20", input?.checked)
    })
  }

  play(event) {
    this.audioTargets.forEach((audio) => {
      if (audio !== event.target) audio.pause()
    })
  }
}
