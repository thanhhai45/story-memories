import { Controller } from "@hotwired/stimulus"

// Form "Tạo video": làm nổi lựa chọn template/nhạc và chỉ cho phát
// một bản nhạc nghe thử tại một thời điểm.
export default class extends Controller {
  static targets = ["option", "audio"]

  connect() {
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
