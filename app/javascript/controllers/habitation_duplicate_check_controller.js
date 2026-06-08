import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["street", "number", "building", "unit", "commercialStatus", "status", "submit"]
  static values = {
    url: String,
    ignoredId: String
  }

  connect() {
    this.timeout = null
    this.hasDuplicate = false
    this.check()
  }

  schedule() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.check(), 350)
  }

  async check() {
    if (!this.identityComplete()) {
      this.hasDuplicate = false
      this.clearStatus()
      this.toggleSubmit(false)
      return
    }

    try {
      const params = new URLSearchParams({
        street: this.streetTarget.value,
        number: this.numberTarget.value,
        building: this.targetValue("building"),
        unit: this.targetValue("unit"),
        status: this.statusValue()
      })
      if (this.hasIgnoredIdValue && this.ignoredIdValue) params.set("ignored_id", this.ignoredIdValue)

      const response = await fetch(`${this.urlValue}?${params.toString()}`, {
        headers: { "Accept": "application/json" }
      })
      const data = await response.json()
      this.hasDuplicate = Boolean(data.duplicate)

      if (this.hasDuplicate) {
        this.showDuplicate(data.matches || [])
      } else {
        this.showAvailable()
      }
      this.toggleSubmit(this.hasDuplicate)
    } catch (error) {
      console.error("[habitation-duplicate-check] erro:", error)
      this.clearStatus()
      this.toggleSubmit(false)
    }
  }

  identityComplete() {
    if (!this.hasStreetTarget || !this.hasNumberTarget) return false

    return [this.streetTarget, this.numberTarget].every((target) => target.value.trim().length > 0) &&
      this.statusValue().trim().length > 0
  }

  statusValue() {
    return this.hasCommercialStatusTarget ? this.commercialStatusTarget.value : ""
  }

  targetValue(name) {
    const targetName = `${name}Target`
    const hasTargetName = `has${name.charAt(0).toUpperCase()}${name.slice(1)}Target`
    return this[hasTargetName] ? this[targetName].value : ""
  }

  showDuplicate(matches) {
    if (!this.hasStatusTarget) return

    this.statusTarget.className = "alert alert-danger small mt-2 mb-0"
    const links = matches.map((match) => {
      const code = match.codigo ? `#${match.codigo}` : `ID ${match.id}`
      return `<a href="${match.edit_url}" class="alert-link" target="_blank" rel="noopener">${this.escapeHtml(code)}</a>`
    }).join(", ")
    this.statusTarget.innerHTML = `Já existe imóvel com este endereço, prédio e unidade${links ? `: ${links}` : "."}. Ajuste os dados antes de continuar.`
  }

  showAvailable() {
    if (!this.hasStatusTarget) return

    this.statusTarget.className = "form-text text-success small mt-2"
    this.statusTarget.textContent = "Endereço sem duplicidade encontrada."
  }

  clearStatus() {
    if (!this.hasStatusTarget) return
    this.statusTarget.className = "form-text text-muted small mt-2"
    this.statusTarget.textContent = ""
  }

  toggleSubmit(disabled) {
    this.submitTargets.forEach((button) => {
      button.disabled = disabled
      button.classList.toggle("disabled", disabled)
    })
  }

  escapeHtml(value) {
    const div = document.createElement("div")
    div.textContent = value
    return div.innerHTML
  }
}
