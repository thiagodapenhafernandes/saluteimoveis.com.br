import { Controller } from "@hotwired/stimulus"
import TomSelect from "tom-select"

// Connects to data-controller="tom-select"
export default class extends Controller {
  static values = {
    options: Object,
    create: Boolean,
    tags: Boolean // New value to enable tagging behavior clearly
  }

  connect() {
    // Default configuration suitable for Bootstrap 5
    const config = {
      plugins: ['remove_button'],
      create: this.createValue || this.tagsValue,
      persist: false,
      allowEmptyOption: true,
      maxItems: (this.element.hasAttribute("multiple") || this.tagsValue) ? null : 1,
      wrapperClass: 'ts-wrapper form-control p-0 border-1',
      onDropdownOpen: () => {
        this.element.closest('.ts-wrapper')?.classList.remove('is-invalid')
      },
      ...this.optionsValue
    }

    // If it's a tag input (jsonb array), we want to behave like one
    if (this.tagsValue) {
      config.create = true
      config.persist = false
      config.createOnBlur = true
    }

    this.tomSelect = new TomSelect(this.element, config)
  }

  disconnect() {
    if (this.tomSelect) {
      this.tomSelect.destroy()
    }
  }
}
