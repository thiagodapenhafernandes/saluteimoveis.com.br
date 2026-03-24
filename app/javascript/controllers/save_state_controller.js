import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submitButton", "cancelButton", "spinner", "label"]
  static values = { submittingText: { type: String, default: "Salvando..." } }

  connect() {
    this.submittingNow = false
    this.defaultLabel = this.hasLabelTarget ? this.labelTarget.textContent : ""
  }

  submitting(event) {
    if (event.defaultPrevented || this.submittingNow) return

    this.submittingNow = true

    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.classList.add("disabled")
    }

    if (this.hasCancelButtonTarget) {
      this.cancelButtonTarget.classList.add("disabled")
      this.cancelButtonTarget.setAttribute("aria-disabled", "true")
      this.cancelButtonTarget.style.pointerEvents = "none"
    }

    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.remove("d-none")
    }

    if (this.hasLabelTarget) {
      this.labelTarget.textContent = this.submittingTextValue
    }
  }

  submitted(event) {
    const successful = Boolean(event?.detail?.success)

    // Em sucesso com redirect, o Turbo navega e este reset é irrelevante.
    // Em erro de validação, precisamos destravar os botões.
    if (!successful) this.reset()
  }

  reset() {
    this.submittingNow = false

    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.classList.remove("disabled")
    }

    if (this.hasCancelButtonTarget) {
      this.cancelButtonTarget.classList.remove("disabled")
      this.cancelButtonTarget.removeAttribute("aria-disabled")
      this.cancelButtonTarget.style.pointerEvents = ""
    }

    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.add("d-none")
    }

    if (this.hasLabelTarget) {
      this.labelTarget.textContent = this.defaultLabel || "Salvar"
    }
  }
}
