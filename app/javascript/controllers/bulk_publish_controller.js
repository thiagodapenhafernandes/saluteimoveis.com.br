import { Controller } from "@hotwired/stimulus"

const CHANNELS_WITH_OPTIONS = new Set([
  "chaves_na_mao",
  "casa_mineira",
  "imovelweb",
  "imovelweb_2",
  "viva_real_vrsync"
])

export default class extends Controller {
  static targets = [
    "item", "master", "toolbar", "count",
    "modal", "modalCount", "form",
    "channelSelect", "actionRadio",
    "channelOptionsWrapper",
    "eligTotal", "eligCount"
  ]
  static values = {
    url: String,
    csrf: String,
    eligibilityUrl: String
  }

  connect() {
    this.updateToolbar()
  }

  // --- Seleção ---

  toggleOne() {
    this.updateToolbar()
    this.syncMaster()
  }

  toggleAll(event) {
    const checked = event.currentTarget.checked
    this.itemTargets.forEach((el) => { el.checked = checked })
    this.updateToolbar()
  }

  clearSelection() {
    this.itemTargets.forEach((el) => { el.checked = false })
    if (this.hasMasterTarget) {
      this.masterTarget.checked = false
      this.masterTarget.indeterminate = false
    }
    this.updateToolbar()
  }

  selectedIds() {
    return this.itemTargets.filter((el) => el.checked).map((el) => el.dataset.id)
  }

  updateToolbar() {
    const count = this.selectedIds().length
    if (this.hasCountTarget) this.countTarget.textContent = count
    if (this.hasToolbarTarget) {
      this.toolbarTarget.classList.toggle("d-none", count === 0)
    }
  }

  syncMaster() {
    if (!this.hasMasterTarget) return
    const total = this.itemTargets.length
    const selected = this.selectedIds().length
    this.masterTarget.checked = total > 0 && selected === total
    this.masterTarget.indeterminate = selected > 0 && selected < total
  }

  // --- Modal ---

  openModal() {
    const ids = this.selectedIds()
    if (ids.length === 0) {
      alert("Selecione ao menos um imóvel.")
      return
    }

    if (this.hasModalCountTarget) this.modalCountTarget.textContent = ids.length
    if (this.hasEligTotalTarget) this.eligTotalTarget.textContent = ids.length
    if (this.hasEligCountTarget) this.eligCountTarget.textContent = "—"

    this.resetForm()
    this.applyChannelVisibility()

    const modalEl = document.getElementById("bulkPublishModal")
    if (!modalEl) return
    const modal = window.bootstrap.Modal.getOrCreateInstance(modalEl)
    modal.show()
  }

  resetForm() {
    if (this.hasChannelSelectTarget) this.channelSelectTarget.value = ""
    this.actionRadioTargets.forEach((radio) => {
      radio.checked = (radio.value === "publicar")
    })
  }

  onChannelChange() {
    this.applyChannelVisibility()
    this.fetchEligibility()
  }

  onActionChange() {
    this.applyChannelVisibility()
    this.fetchEligibility()
  }

  currentChannel() {
    return this.hasChannelSelectTarget ? this.channelSelectTarget.value : ""
  }

  currentActionType() {
    const radio = this.actionRadioTargets.find((el) => el.checked)
    return radio ? radio.value : "publicar"
  }

  applyChannelVisibility() {
    if (!this.hasChannelOptionsWrapperTarget) return

    const channel = this.currentChannel()
    const action = this.currentActionType()
    const shouldShow = action === "publicar" && CHANNELS_WITH_OPTIONS.has(channel)

    this.channelOptionsWrapperTarget.classList.toggle("d-none", !shouldShow)

    const blocks = this.channelOptionsWrapperTarget.querySelectorAll(".channel-options-block")
    blocks.forEach((block) => {
      block.classList.toggle("d-none", block.dataset.channel !== channel)
    })
  }

  async fetchEligibility() {
    if (!this.hasEligCountTarget) return

    const channel = this.currentChannel()
    const action = this.currentActionType()
    const ids = this.selectedIds()

    if (!channel || ids.length === 0) {
      this.eligCountTarget.textContent = "—"
      return
    }

    this.eligCountTarget.textContent = "…"

    const formData = new FormData()
    ids.forEach((id) => formData.append("selected_ids[]", id))
    formData.append("channel", channel)
    formData.append("action_type", action)

    try {
      const response = await fetch(this.eligibilityUrlValue, {
        method: "POST",
        body: formData,
        headers: {
          "X-CSRF-Token": this.csrfValue,
          "Accept": "application/json"
        },
        credentials: "same-origin"
      })
      const data = await response.json().catch(() => ({}))
      if (response.ok) {
        this.eligCountTarget.textContent = data.eligible ?? "—"
      } else {
        this.eligCountTarget.textContent = "—"
      }
    } catch (_) {
      this.eligCountTarget.textContent = "—"
    }
  }

  // --- Submit ---

  async submit(event) {
    event.preventDefault()

    const ids = this.selectedIds()
    if (ids.length === 0) {
      alert("Selecione ao menos um imóvel.")
      return
    }

    const channel = this.currentChannel()
    if (!channel) {
      alert("Selecione um canal de divulgação.")
      return
    }

    const form = document.getElementById("bulkPublishForm")
    if (!form) return

    const formData = new FormData(form)
    // Converte `channel` single-select em `channels[]` esperado pelo backend
    formData.delete("channel")
    formData.append("channels[]", channel)
    ids.forEach((id) => formData.append("selected_ids[]", id))

    const button = event.currentTarget
    const originalHTML = button.innerHTML
    button.disabled = true
    button.innerHTML = '<span class="spinner-border spinner-border-sm me-1"></span> Processando...'

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        body: formData,
        headers: {
          "X-CSRF-Token": this.csrfValue,
          "Accept": "application/json"
        },
        credentials: "same-origin"
      })

      const data = await response.json().catch(() => ({}))

      if (response.ok) {
        const modalEl = document.getElementById("bulkPublishModal")
        const modal = window.bootstrap.Modal.getOrCreateInstance(modalEl)
        modal.hide()
        alert(`${data.updated || ids.length} imóvel(is) atualizado(s) com sucesso.`)
        window.location.reload()
      } else {
        alert(`Erro: ${data.error || "Falha na requisição."}`)
        button.disabled = false
        button.innerHTML = originalHTML
      }
    } catch (err) {
      alert(`Erro de conexão: ${err.message}`)
      button.disabled = false
      button.innerHTML = originalHTML
    }
  }
}
