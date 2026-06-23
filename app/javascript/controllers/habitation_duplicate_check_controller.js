import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["street", "number", "building", "unit", "complement", "category", "commercialStatus", "comparison", "status", "submit", "title", "contentSubmit"]
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
      this.updateButtons()
      return
    }

    try {
      const params = new URLSearchParams({
        street: this.streetTarget.value,
        number: this.numberTarget.value,
        building: this.targetValue("building"),
        unit: this.targetValue("unit"),
        complement: this.targetValue("complement"),
        category: this.targetValue("category"),
        status: this.statusValue(),
        comparison: this.comparisonValue()
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
      this.updateButtons()
    } catch (error) {
      console.error("[habitation-duplicate-check] erro:", error)
      this.hasDuplicate = false
      this.clearStatus()
      this.updateButtons()
    }
  }

  identityComplete() {
    if (!this.hasStreetTarget || !this.hasNumberTarget) return false

    return [this.streetTarget, this.numberTarget].every((target) => target.value.trim().length > 0) &&
      this.statusValue().trim().length > 0 &&
      this.comparisonIdentityComplete()
  }

  comparisonIdentityComplete() {
    if (this.comparisonValue() === "unit") return this.targetValue("unit").trim().length > 0
    if (this.comparisonValue() === "condominium_unit") {
      return this.targetValue("unit").trim().length > 0 || this.targetValue("complement").trim().length > 0
    }

    return true
  }

  statusValue() {
    return this.hasCommercialStatusTarget ? this.commercialStatusTarget.value : ""
  }

  targetValue(name) {
    const targetName = `${name}Target`
    const hasTargetName = `has${name.charAt(0).toUpperCase()}${name.slice(1)}Target`
    return this[hasTargetName] ? this[targetName].value : ""
  }

  comparisonValue() {
    if (this.complementBlockCategorySelected() && (this.targetValue("unit").trim().length > 0 || this.targetValue("complement").trim().length > 0)) {
      return "condominium_unit"
    }

    return this.hasComparisonTarget ? this.comparisonTarget.value : ""
  }

  complementBlockCategorySelected() {
    const category = this.targetValue("category").normalize("NFD").replace(/\p{Diacritic}/gu, "").toLowerCase()
    return category.includes("casa em condominio") || category.includes("terreno")
  }

  showDuplicate(matches) {
    if (!this.hasStatusTarget) return

    this.statusTarget.className = "alert alert-danger small mt-2 mb-0"
    const links = matches.map((match) => {
      const code = match.codigo ? `#${match.codigo}` : `ID ${match.id}`
      return `<a href="${match.edit_url}" class="alert-link" target="_blank" rel="noopener">${this.escapeHtml(code)}</a>`
    }).join(", ")
    const identity = this.comparisonValue() === "unit"
      ? "este endereço, unidade e status comercial"
      : (this.comparisonValue() === "condominium_unit" ? "este endereço, complemento, bloco e status comercial" : "este endereço e status comercial")
    this.statusTarget.innerHTML = `Já existe imóvel com ${identity}${links ? `: ${links}` : "."}. Ajuste os dados antes de salvar.`
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

  // Atualiza o estado dos botões. Todos os botões de envio são bloqueados quando
  // há endereço duplicado. Os botões de conclusão administrativa ("Salvar Interno"
  // e "Devolver/Enviar para corretor") também ficam bloqueados enquanto faltar
  // título ou descrição (internet).
  updateButtons() {
    const contentMissing = this.contentMissing()

    this.submitTargets.forEach((button) => {
      const requiresContent = this.contentSubmitTargets.includes(button)
      const disabled = this.hasDuplicate || (requiresContent && contentMissing)
      button.disabled = disabled
      button.classList.toggle("disabled", disabled)
      if (requiresContent) {
        button.title = (contentMissing && !this.hasDuplicate)
          ? "Preencha o título e a descrição do imóvel para concluir."
          : ""
      }
    })
  }

  contentMissing() {
    return this.titleBlank() || this.descriptionBlank()
  }

  titleBlank() {
    if (!this.hasTitleTarget) return false
    return this.titleTarget.value.trim().length === 0
  }

  descriptionBlank() {
    const input = this.element.querySelector('input[name="habitation[descricao_web]"]')
    if (!input) return false
    const text = (input.value || "").replace(/<[^>]*>/g, "").replace(/&nbsp;/gi, " ").trim()
    return text.length === 0
  }

  refreshContent() {
    this.updateButtons()
  }

  escapeHtml(value) {
    const div = document.createElement("div")
    div.textContent = value
    return div.innerHTML
  }
}
