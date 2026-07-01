import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submitButton", "cancelButton", "spinner", "label", "choice", "modal", "toast", "toastBody", "leaveModal"]
  static values = { submittingText: { type: String, default: "Salvando..." } }

  connect() {
    this.submittingNow = false
    this.saveOptionsConfirmed = false
    this.saveOptionsSubmitter = null
    this.defaultLabel = this.hasLabelTarget ? this.labelTarget.textContent : ""
    this.directUploadProgress = new Map()

    this.boundDirectUploadsStart = this.directUploadsStart.bind(this)
    this.boundDirectUploadProgress = this.directUploadProgressed.bind(this)
    this.boundDirectUploadsEnd = this.directUploadsEnd.bind(this)
    this.boundDirectUploadError = this.directUploadError.bind(this)

    this.element.addEventListener("direct-uploads:start", this.boundDirectUploadsStart)
    this.element.addEventListener("direct-upload:progress", this.boundDirectUploadProgress)
    this.element.addEventListener("direct-uploads:end", this.boundDirectUploadsEnd)
    this.element.addEventListener("direct-upload:error", this.boundDirectUploadError)

    // Aviso de alterações não salvas: marca a ficha como "suja" quando o
    // usuário edita algum campo e avisa antes de sair sem salvar.
    this.formDirty = false
    this.allowLeave = false
    this.readyForDirty = false
    this.dirtyReadyTimer = window.setTimeout(() => { this.readyForDirty = true }, 1200)

    this.boundMarkDirty = this.markDirty.bind(this)
    this.element.addEventListener("input", this.boundMarkDirty)
    this.element.addEventListener("change", this.boundMarkDirty)

    this.boundBeforeUnload = this.beforeUnload.bind(this)
    window.addEventListener("beforeunload", this.boundBeforeUnload)

    this.boundLeaveGuard = this.leaveGuard.bind(this)
    this.leaveGuardLinks = Array.from(document.querySelectorAll("[data-save-state-leave-guard]"))
    this.leaveGuardLinks.forEach((link) => link.addEventListener("click", this.boundLeaveGuard))
  }

  disconnect() {
    this.element.removeEventListener("direct-uploads:start", this.boundDirectUploadsStart)
    this.element.removeEventListener("direct-upload:progress", this.boundDirectUploadProgress)
    this.element.removeEventListener("direct-uploads:end", this.boundDirectUploadsEnd)
    this.element.removeEventListener("direct-upload:error", this.boundDirectUploadError)

    this.element.removeEventListener("input", this.boundMarkDirty)
    this.element.removeEventListener("change", this.boundMarkDirty)
    window.removeEventListener("beforeunload", this.boundBeforeUnload)
    if (this.dirtyReadyTimer) window.clearTimeout(this.dirtyReadyTimer)
    if (this.leaveGuardLinks) {
      this.leaveGuardLinks.forEach((link) => link.removeEventListener("click", this.boundLeaveGuard))
    }
  }

  markDirty() {
    if (!this.readyForDirty || this.submittingNow) return
    this.formDirty = true
  }

  beforeUnload(event) {
    if (!this.formDirty || this.submittingNow || this.allowLeave) return
    event.preventDefault()
    event.returnValue = ""
    return ""
  }

  leaveGuard(event) {
    if (!this.formDirty || this.submittingNow || this.allowLeave) return

    // Intercepta a navegação e abre um pop up com as opções (como no Vista):
    // Salvar e sair / Sair sem salvar / Cancelar.
    event.preventDefault()
    this.pendingLeaveUrl = event.currentTarget && event.currentTarget.href ? event.currentTarget.href : null

    const bootstrapElement = window.bootstrap || (typeof bootstrap !== "undefined" ? bootstrap : null)
    if (bootstrapElement?.Modal && this.hasLeaveModalTarget) {
      bootstrapElement.Modal.getOrCreateInstance(this.leaveModalTarget).show()
    } else if (window.confirm("Você tem alterações não salvas. Deseja sair sem salvar?")) {
      // Fallback quando o Bootstrap não está disponível.
      this.leaveWithoutSaving()
    }
  }

  hideLeaveModal() {
    const bootstrapElement = window.bootstrap || (typeof bootstrap !== "undefined" ? bootstrap : null)
    if (bootstrapElement?.Modal && this.hasLeaveModalTarget) {
      bootstrapElement.Modal.getOrCreateInstance(this.leaveModalTarget).hide()
    }
  }

  // "Salvar e sair": salva a ficha (fluxo normal) e sai para o catálogo.
  saveAndLeave() {
    this.allowLeave = true
    if (this.hasChoiceTarget) this.choiceTarget.value = "exit"
    this.saveOptionsConfirmed = true
    this.hideLeaveModal()
    window.setTimeout(() => this.requestConfirmedSubmit(), 150)
  }

  // "Sair sem salvar": descarta as alterações e vai para o destino clicado.
  leaveWithoutSaving() {
    this.allowLeave = true
    this.hideLeaveModal()
    if (this.pendingLeaveUrl) {
      window.location.href = this.pendingLeaveUrl
    } else {
      window.history.back()
    }
  }

  // "Cancelar": permanece na ficha.
  cancelLeave() {
    this.pendingLeaveUrl = null
  }

  confirm(event) {
    if (!this.hasSaveOptionsTargets || this.saveOptionsConfirmed || this.skipSaveOptionsFor(event.submitter)) {
      this.saveOptionsConfirmed = false
      return
    }

    event.preventDefault()
    event.stopImmediatePropagation()
    this.saveOptionsSubmitter = event.submitter
    this.showToast("Escolha como deseja concluir o salvamento.")
    this.openModal()
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

  directUploadsStart() {
    this.submittingNow = true
    this.directUploadProgress.clear()
    this.disableActions()
    this.showSpinner()
    this.setLabel("Enviando fotos...")
  }

  directUploadProgressed(event) {
    const id = event?.detail?.id
    const progress = Number(event?.detail?.progress || 0)
    if (!id) return

    this.directUploadProgress.set(id, progress)
    const values = Array.from(this.directUploadProgress.values())
    const average = values.length ? Math.round(values.reduce((sum, value) => sum + value, 0) / values.length) : progress
    this.setLabel(`Enviando fotos ${average}%`)
  }

  directUploadsEnd() {
    this.setLabel("Finalizando cadastro...")
  }

  directUploadError(event) {
    event.preventDefault()
    this.showToast("Não foi possível enviar as fotos. Verifique sua conexão e tente novamente.")
    this.reset()
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

  submitStay(event) {
    event.preventDefault()
    this.submitWithChoice("stay", "Salvando e permanecendo na ficha de cadastro...")
  }

  submitExit(event) {
    event.preventDefault()
    this.submitWithChoice("exit", "Salvando e saindo para o catálogo...")
  }

  cancel(event) {
    event.preventDefault()
    this.hideModal()
    this.showToast("Salvamento cancelado. Nenhuma alteração foi enviada.")
  }

  submitWithChoice(choice, message) {
    this.choiceTarget.value = choice
    this.saveOptionsConfirmed = true
    this.hideModal()
    this.showToast(message)
    window.setTimeout(() => this.requestConfirmedSubmit(), 200)
  }

  skipSaveOptionsFor(submitter) {
    return submitter?.name === "release_to_broker_after_save"
  }

  disableActions() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.classList.add("disabled")
    }

    if (this.hasCancelButtonTarget) {
      this.cancelButtonTarget.classList.add("disabled")
      this.cancelButtonTarget.setAttribute("aria-disabled", "true")
      this.cancelButtonTarget.style.pointerEvents = "none"
    }
  }

  showSpinner() {
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.remove("d-none")
    }
  }

  setLabel(text) {
    if (this.hasLabelTarget) {
      this.labelTarget.textContent = text
    }
  }

  get hasSaveOptionsTargets() {
    return this.hasChoiceTarget && this.hasModalTarget
  }

  openModal() {
    const bootstrapElement = window.bootstrap || (typeof bootstrap !== "undefined" ? bootstrap : null)

    if (bootstrapElement?.Modal) {
      bootstrapElement.Modal.getOrCreateInstance(this.modalTarget).show()
      return
    }

    this.choiceTarget.value = "exit"
    this.saveOptionsConfirmed = true
    this.requestConfirmedSubmit()
  }

  hideModal() {
    const bootstrapElement = window.bootstrap || (typeof bootstrap !== "undefined" ? bootstrap : null)
    if (!bootstrapElement?.Modal || !this.hasModalTarget) return

    bootstrapElement.Modal.getOrCreateInstance(this.modalTarget).hide()
  }

  showToast(message) {
    if (!this.hasToastTarget || !this.hasToastBodyTarget) return

    this.toastBodyTarget.textContent = message
    const bootstrapElement = window.bootstrap || (typeof bootstrap !== "undefined" ? bootstrap : null)

    if (bootstrapElement?.Toast) {
      bootstrapElement.Toast.getOrCreateInstance(this.toastTarget, { delay: 3500 }).show()
      return
    }

    this.toastTarget.classList.add("show")
    window.setTimeout(() => this.toastTarget.classList.remove("show"), 3500)
  }

  requestConfirmedSubmit() {
    if (this.saveOptionsSubmitter) {
      this.element.requestSubmit(this.saveOptionsSubmitter)
    } else {
      this.element.requestSubmit()
    }
  }
}
