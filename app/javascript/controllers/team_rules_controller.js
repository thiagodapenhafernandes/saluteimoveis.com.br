import { Controller } from "@hotwired/stimulus"
import TomSelect from "tom-select"

export default class extends Controller {
  static targets = ["agentSelect", "list", "template"]
  static values = {
    structure: Object
  }

  connect() {
    this.initAgentSelect()
  }

  initAgentSelect() {
    if (!this.hasAgentSelectTarget) return
    if (this.agentSelectInstance) return

    this.agentSelectInstance = new TomSelect(this.agentSelectTarget, {
      plugins: ['remove_button'],
      placeholder: "Selecione para adicionar...",
      maxOptions: null
    })
  }

  addAgent(event) {
    event.preventDefault()
    const selectedId = this.agentSelectInstance.getValue()
    if (!selectedId) return

    const option = this.agentSelectInstance.options[selectedId]
    const agentName = option ? option.text : "Novo Corretor"

    // Check if already in list
    const existingInputs = this.listTarget.querySelectorAll(`input[name*="[admin_user_id]"]`)
    for (let input of existingInputs) {
      if (input.value == selectedId) {
        const wrapper = input.closest(".nested-form-wrapper")
        if (wrapper && wrapper.style.display === "none") {
          wrapper.style.display = ""
          wrapper.querySelector('input[name*="[_destroy]"]').value = "0"
          this.agentSelectInstance.clear()

          // Re-apply visibility check for restored items
          this.updateVisibility(wrapper)
          return
        }
        alert("Este corretor já está na lista.")
        this.agentSelectInstance.clear()
        return
      }
    }

    const content = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, new Date().getTime())
    this.listTarget.insertAdjacentHTML('beforeend', content)

    // Update the inserted row with correct data
    const newRow = this.listTarget.lastElementChild
    newRow.querySelector('input[name*="[admin_user_id]"]').value = selectedId
    newRow.querySelector('h6').textContent = agentName
    newRow.querySelector('.text-muted.extra-small').textContent = ''
    newRow.querySelector('.rounded-circle span').textContent = agentName.substring(0, 2).toUpperCase()

    // Reset select
    this.agentSelectInstance.clear()

    // Ensure correct visibility based on current mode
    this.updateVisibility(newRow)
  }

  remove(event) {
    event.preventDefault()
    const wrapper = event.target.closest(".nested-form-wrapper")

    if (wrapper.dataset.newRecord === "true") {
      wrapper.remove()
    } else {
      wrapper.style.display = "none"
      wrapper.querySelector('input[name*="[_destroy]"]').value = "1"
    }
  }

  updateVisibility(row) {
    const currentMode = document.querySelector('input[name="distribution_rule[distribution_mode]"]:checked')?.value || 'rotary'
    const performanceField = row.querySelector('.performance-field')
    const rotaryField = row.querySelector('.rotary-field')

    if (performanceField) performanceField.classList.toggle('d-none', currentMode !== 'performance')
    if (rotaryField) rotaryField.classList.toggle('d-none', currentMode !== 'rotary')
  }

  filterAgents(event) {
    const managerId = event.target.value
    if (!this.agentSelectInstance) return

    if (!managerId) {
      this.restoreAllOptions()
      return
    }

    const team = this.structureValue[managerId]
    if (!team) return

    this.agentSelectInstance.clearOptions()
    team.agents.forEach(agent => {
      this.agentSelectInstance.addOption({
        value: agent.id,
        text: agent.name
      })
    })
    this.agentSelectInstance.refreshOptions(false)
  }

  restoreAllOptions() {
    this.agentSelectInstance.clearOptions()
    Object.values(this.structureValue).forEach(team => {
      team.agents.forEach(agent => {
        this.agentSelectInstance.addOption({
          value: agent.id,
          text: agent.name
        })
      })
    })
    this.agentSelectInstance.refreshOptions(false)
  }
}
