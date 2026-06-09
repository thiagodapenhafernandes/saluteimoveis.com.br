import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["logo", "positionInput"]

  update() {
    if (!this.hasLogoTarget) return

    const selected = this.positionInputTargets.find((input) => input.checked)
    if (!selected) return

    this.logoTarget.classList.remove(
      "watermark-position-bottom_left",
      "watermark-position-bottom_right",
      "watermark-position-center"
    )
    this.logoTarget.classList.add(`watermark-position-${selected.value}`)
  }
}
