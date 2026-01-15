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
        tab.classList.remove('text-gray-600', 'hover:text-blue-three', 'bg-transparent')
        tab.classList.add('bg-hero-button', 'text-hero-button-text', 'shadow-sm')
      } else {
        tab.classList.add('text-gray-600', 'hover:text-blue-three', 'bg-transparent')
        tab.classList.remove('bg-hero-button', 'text-hero-button-text', 'shadow-sm')
      }
    })
  }

  openAdvanced() {
    // Dispatch event to open advanced filters (likely sidebar in Habitation index)
    // Or if we are on Home, we might need a different logic or redirect to search with modal open
    const sidebar = document.querySelector('[data-controller="advanced-filters"]')
    if (sidebar) {
      this.dispatch("open-advanced") // Custom integration
      // If the controller is already on the page:
      const controller = this.application.getControllerForElementAndIdentifier(sidebar, "advanced-filters")
      if (controller) controller.open()
    } else {
      // Fallback: redirect to habitations with a flag
      window.location.href = "/imoveis?open_filters=true"
    }
  }
}
