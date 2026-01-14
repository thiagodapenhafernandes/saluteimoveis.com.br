import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "overlay"]

  connect() {
    // Close sidebar on escape key
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') this.close()
    })
  }

  open() {
    this.sidebarTarget.classList.remove('translate-x-full')
    this.overlayTarget.classList.remove('hidden')
    document.body.classList.add('overflow-hidden')
  }

  close() {
    this.sidebarTarget.classList.add('translate-x-full')
    this.overlayTarget.classList.add('hidden')
    document.body.classList.remove('overflow-hidden')
  }
}
