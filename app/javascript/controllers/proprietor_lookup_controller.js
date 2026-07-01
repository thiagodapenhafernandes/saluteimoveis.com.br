import { Controller } from "@hotwired/stimulus"

// Busca um proprietário já cadastrado pelo telefone (ou CPF/CNPJ) e preenche
// os campos da ficha de captação, evitando cadastro duplicado.
export default class extends Controller {
  static targets = ["phone", "cpf", "name", "email", "city", "status", "editLink"]
  static values = { url: String }

  async lookup() {
    const phone = this.hasPhoneTarget ? this.phoneTarget.value.trim() : ""
    const cpf = this.hasCpfTarget ? this.cpfTarget.value.trim() : ""

    if (phone.replace(/\D/g, "").length < 8 && cpf.replace(/\D/g, "").length < 11) {
      this.setStatus("Informe o telefone (ou CPF/CNPJ) para buscar.", "warning")
      return
    }

    this.setStatus("Buscando na base...", "info")

    try {
      const params = new URLSearchParams()
      if (phone) params.set("phone", phone)
      if (cpf) params.set("cpf_cnpj", cpf)
      const resp = await fetch(`${this.urlValue}?${params.toString()}`, {
        headers: { Accept: "application/json" }
      })
      const data = await resp.json()

      if (data.found) {
        this.fill(data.proprietor)
        this.setStatus(`Proprietário já cadastrado: ${data.proprietor.name}. Campos preenchidos — confira e complete o que faltar.`, "success", data.proprietor.edit_url)
      } else {
        this.setStatus("Nenhum proprietário encontrado. Preencha os dados para cadastrar um novo.", "info")
      }
    } catch (e) {
      this.setStatus("Não foi possível buscar agora. Preencha manualmente.", "warning")
    }
  }

  fill(p) {
    this.assign(this.hasNameTarget && this.nameTarget, p.name)
    this.assign(this.hasEmailTarget && this.emailTarget, p.email)
    this.assign(this.hasCityTarget && this.cityTarget, p.city)
    this.assign(this.hasCpfTarget && this.cpfTarget, p.cpf_cnpj)
    if (this.hasPhoneTarget && !this.phoneTarget.value) {
      this.phoneTarget.value = p.mobile_phone || p.phone_primary || ""
    }
  }

  assign(field, value) {
    if (!field || value == null || value === "") return
    field.value = value
    field.dispatchEvent(new Event("input", { bubbles: true }))
  }

  setStatus(message, kind, editUrl) {
    if (!this.hasStatusTarget) return
    const colors = { info: "text-muted", success: "text-success", warning: "text-danger" }
    this.statusTarget.className = `small mt-1 ${colors[kind] || "text-muted"}`
    this.statusTarget.textContent = message
    if (this.hasEditLinkTarget) {
      if (editUrl) {
        this.editLinkTarget.href = editUrl
        this.editLinkTarget.classList.remove("d-none")
      } else {
        this.editLinkTarget.classList.add("d-none")
      }
    }
  }
}
