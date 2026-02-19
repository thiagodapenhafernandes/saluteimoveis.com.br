import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "button"]

  toggle(event) {
    event.preventDefault()
    this.contentTarget.classList.toggle("show")
    this.buttonTarget.classList.toggle("collapsed")

    const expanded = this.contentTarget.classList.contains("show")
    this.buttonTarget.setAttribute("aria-expanded", expanded)
  }
}
