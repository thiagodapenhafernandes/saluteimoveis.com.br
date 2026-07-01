import { Controller } from "@hotwired/stimulus"

// Mantém um link "Editar cadastro" apontando para o proprietário selecionado,
// permitindo abrir a ficha completa para adicionar mais dados.
export default class extends Controller {
  static targets = ["select", "link"]
  static values = { urlTemplate: String }

  connect() {
    this.update()
  }

  update() {
    if (!this.hasSelectTarget || !this.hasLinkTarget) return
    const id = this.selectTarget.value

    if (id) {
      this.linkTarget.href = this.urlTemplateValue.replace("__ID__", id)
      this.linkTarget.classList.remove("d-none")
    } else {
      this.linkTarget.classList.add("d-none")
    }
  }
}
