import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Connects to data-controller="photo-upload"
export default class extends Controller {
  static targets = ["input", "orderInput", "apiOrderInput", "previewContainer"]

  connect() {
    this.boundHandleDragOver = this.handleDragOver.bind(this)
    this.boundHandleDrop = this.handleDrop.bind(this)
    this.boundHandleDragLeave = this.handleDragLeave.bind(this)

    this.initSortable()

    // Drag and Drop
    this.element.addEventListener('dragover', this.boundHandleDragOver)
    this.element.addEventListener('drop', this.boundHandleDrop)
    this.element.addEventListener('dragleave', this.boundHandleDragLeave)
  }

  disconnect() {
    if (this.sortable) this.sortable.destroy()
    this.element.removeEventListener('dragover', this.boundHandleDragOver)
    this.element.removeEventListener('drop', this.boundHandleDrop)
    this.element.removeEventListener('dragleave', this.boundHandleDragLeave)
  }

  handleDragOver(e) {
    e.preventDefault()
    e.stopPropagation()
    this.element.classList.add('border-primary', 'bg-light-subtle')
  }

  handleDragLeave(e) {
    e.preventDefault()
    this.element.classList.remove('border-primary', 'bg-light-subtle')
  }

  handleDrop(e) {
    e.preventDefault()
    e.stopPropagation()
    this.element.classList.remove('border-primary', 'bg-light-subtle')

    if (e.dataTransfer && e.dataTransfer.files.length > 0) {
      if (this.hasInputTarget) {
        this.inputTarget.files = e.dataTransfer.files
        // Trigger change event to run preview
        this.inputTarget.dispatchEvent(new Event('change'))
      }
    }
  }

  initSortable() {
    // Only initialize if container exists
    if (!this.hasPreviewContainerTarget) return

    this.sortable = new Sortable(this.previewContainerTarget, {
      animation: 150,
      ghostClass: 'sortable-ghost',
      draggable: '.draggable-item',
      onEnd: (evt) => {
        this.updateOrder()
      }
    })
  }

  updateOrder() {
    if (this.hasOrderInputTarget) {
      const ids = Array.from(this.previewContainerTarget.querySelectorAll('.attached-photo-item'))
      .map(el => el.dataset.id)
      .filter(id => id) // Filter out new uploads (no ID yet) or empty IDs

      this.orderInputTarget.value = ids.join(',')
    }

    if (this.hasApiOrderInputTarget) {
      const apiIndexes = Array.from(this.previewContainerTarget.querySelectorAll('.api-picture-item'))
        .map(el => el.dataset.apiIndex)
        .filter(index => index)

      this.apiOrderInputTarget.value = apiIndexes.join(',')
    }
  }

  preview(event) {
    const files = event.target.files

    // Clear previous NEW previews logic
    const existingPreviews = this.previewContainerTarget.querySelectorAll('.new-photo-preview')
    existingPreviews.forEach(el => el.remove())

    if (files.length === 0) return

    Array.from(files).forEach(file => {
      const reader = new FileReader()

      reader.onload = (e) => {
        const imgContainer = document.createElement("div")
        // Match standard column classes and add draggable-item
        imgContainer.classList.add("col-6", "col-md-3", "col-lg-2", "draggable-item", "new-photo-preview")

        imgContainer.innerHTML = `
          <div class="position-relative ratio ratio-1x1 group-hover cursor-grab">
            <img src="${e.target.result}" class="rounded border object-fit-cover w-100 h-100" alt="${file.name}">
            <div class="position-absolute top-0 start-0 w-100 h-100 d-flex align-items-center justify-content-center bg-black bg-opacity-25 opacity-0 hover-opacity-100 transition-opacity">
              <span class="badge bg-success">Nova</span>
            </div>
          </div>
        `
        this.previewContainerTarget.appendChild(imgContainer)
      }

      reader.readAsDataURL(file)
    })
  }
}
