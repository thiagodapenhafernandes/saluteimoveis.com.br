import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "input"]

  connect() {
    // Set initial state based on input value or default
    this.updateTabs(this.inputTarget.value || 'venda')
  }

  switch(event) {
    const value = event.currentTarget.dataset.value
    this.inputTarget.value = value
    this.updateTabs(value)
  }

  updateTabs(activeValue) {
    this.tabTargets.forEach(tab => {
      if (tab.dataset.value === activeValue) {
        tab.classList.remove('text-gray-600', 'hover:text-blue-three')
        tab.classList.add('bg-golden-one', 'text-white', 'shadow-sm')
      } else {
        tab.classList.add('text-gray-600', 'hover:text-blue-three')
        tab.classList.remove('bg-golden-one', 'text-white', 'shadow-sm')
      }
    })
  }
}
