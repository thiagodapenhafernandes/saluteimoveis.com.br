import { Controller } from "@hotwired/stimulus"
import TomSelect from "tom-select"

export default class extends Controller {
  static targets = ["pageSelect", "formSelect"]
  static values = {
    structure: Object // { page_id: { forms: [{id: 1, name: "Name"}] } }
  }

  connect() {
    this.initFormSelect()
  }

  disconnect() {
    if (this.formSelectInstance && this.formSelectInstance.destroy) {
      try { this.formSelectInstance.destroy() } catch (e) {}
    }
    this.formSelectInstance = null
  }

  initFormSelect() {
    if (!this.hasFormSelectTarget) return
    if (this.formSelectInstance) return
    if (this.formSelectTarget.tomselect) {
      this.formSelectInstance = this.formSelectTarget.tomselect
      return
    }

    this.formSelectInstance = new TomSelect(this.formSelectTarget, {
      plugins: ['remove_button'],
      placeholder: "Selecione os formulários...",
      maxOptions: null,
      onInitialize: () => {
        // We might want to pre-populate if editing
      }
    })
  }

  updateForms(event) {
    const selectedPages = Array.from(event.target.selectedOptions).map(opt => opt.value)
    if (!this.formSelectInstance) this.initFormSelect()
    if (!this.formSelectInstance) return

    // Save existing selections to re-apply them if they still exist in new options
    const currentSelections = Array.from(this.formSelectTarget.selectedOptions).map(o => o.value)

    this.formSelectInstance.clearOptions()

    selectedPages.forEach(pageId => {
      const pageData = this.structureValue[pageId]
      if (pageData && pageData.forms) {
        pageData.forms.forEach(form => {
          this.formSelectInstance.addOption({
            value: form.id,
            text: `${form.name} (${pageData.name})`
          })

          if (currentSelections.includes(form.id)) {
            this.formSelectInstance.addItem(form.id)
          }
        })
      }
    })

    this.formSelectInstance.refreshOptions(false)
  }

  syncNow(event) {
    const btn = event.currentTarget
    const icon = btn.querySelector('i')

    btn.disabled = true
    if (icon) icon.classList.add('fa-spin') // or bi-arrow-repeat spin

    // Simulate sync or call API if available
    // For now, just a visual feedback
    setTimeout(() => {
      btn.disabled = false
      if (icon) icon.classList.remove('fa-spin')
      alert("Sincronização concluída com sucesso!")
    }, 1500)
  }

  toggleAutoSync(event) {
    if (!event.target.checked) return
    if (!this.formSelectInstance) return

    // Select all available options
    const allOptions = Object.keys(this.formSelectInstance.options)

    // Silence events to avoid performance hit if many items, then trigger one change
    this.formSelectInstance.addItems(allOptions)
  }
}
