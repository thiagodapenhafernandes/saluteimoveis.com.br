import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["represamentoSection", "pocketSection", "metaSection", "webhookSection"]

  connect() {
    this.toggleRepresamento()
    this.togglePocket()
    this.toggleMeta()
    this.toggleMeta()
    this.toggleWebhook()
    this.toggleMode()
  }

  toggleRepresamento(event) {
    const checkbox = event ? event.target : this.element.querySelector('#checkRepresamento')
    if (this.hasRepresamentoSectionTarget && checkbox) {
      this.represamentoSectionTarget.classList.toggle("d-none", !checkbox.checked)
    }
  }

  togglePocket(event) {
    const checkbox = event ? event.target : this.element.querySelector('#checkPocket')
    if (this.hasPocketSectionTarget && checkbox) {
      this.pocketSectionTarget.classList.toggle("d-none", !checkbox.checked)
    }
  }

  toggleMeta(event) {
    const checkbox = event ? event.target : this.element.querySelector('[name="distribution_rule[source_meta]"]')
    if (this.hasMetaSectionTarget && checkbox) {
      this.metaSectionTarget.classList.toggle("d-none", !checkbox.checked)
    }
  }

  toggleWebhook(event) {
    const checkbox = event ? event.target : this.element.querySelector('[name="distribution_rule[source_webhook]"]')
    if (this.hasWebhookSectionTarget && checkbox) {
      this.webhookSectionTarget.classList.toggle("d-none", !checkbox.checked)
    }
  }

  toggleMode(event) {
    const selectedMode = event ? event.target.value : (this.element.querySelector('input[name="distribution_rule[distribution_mode]"]:checked')?.value || 'rotary')

    const performanceFields = document.querySelectorAll('.performance-field')
    const rotaryFields = document.querySelectorAll('.rotary-field')

    performanceFields.forEach(el => el.classList.toggle('d-none', selectedMode !== 'performance'))
    rotaryFields.forEach(el => el.classList.toggle('d-none', selectedMode !== 'rotary'))
  }
}
