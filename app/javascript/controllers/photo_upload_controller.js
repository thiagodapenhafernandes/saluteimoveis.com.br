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
      handle: '.media-photo-drag-handle',
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
        .filter(index => index !== undefined && index !== null && index !== '')

      this.apiOrderInputTarget.value = apiIndexes.join(',')
    }
  }

  setFeatured(event) {
    event.preventDefault()
    event.stopPropagation()

    const item = event.currentTarget.closest('.draggable-item')
    if (!item || !this.hasPreviewContainerTarget) return

    this.previewContainerTarget.prepend(item)
    this.updateOrder()
    this.refreshPhotoBadges()
  }

  refreshPhotoBadges() {
    const items = Array.from(this.previewContainerTarget.querySelectorAll('.draggable-item'))

    items.forEach((item, index) => {
      const positionBadge = item.querySelector('[data-photo-position-badge]')
      if (positionBadge) positionBadge.textContent = `#${index + 1}`

      const featuredContainer = item.querySelector('[data-photo-featured-control]')
      if (!featuredContainer) return

      if (index === 0) {
        featuredContainer.innerHTML = `
          <span class="badge bg-warning text-dark border shadow-sm">
            <i class="bi bi-star-fill me-1"></i>Destaque
          </span>
        `
      } else {
        featuredContainer.innerHTML = `
          <button type="button"
                  class="media-photo-feature-button btn btn-sm btn-warning border py-0 px-1 fw-semibold"
                  title="Definir como destaque"
                  data-action="photo-upload#setFeatured">
            <i class="bi bi-star"></i>
          </button>
        `
      }
    })
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
          <div class="position-relative ratio ratio-1x1 group-hover media-photo-tile">
            <img src="${e.target.result}" class="rounded border object-fit-cover w-100 h-100" alt="${file.name}">
            <div class="media-photo-overlay position-absolute d-flex flex-column justify-content-between p-1">
              <div class="d-flex justify-content-between align-items-start gap-1">
                <span class="badge bg-dark bg-opacity-75 border shadow-sm" data-photo-position-badge>#</span>
                <span class="badge bg-success border shadow-sm">Nova</span>
              </div>
              <div class="d-flex justify-content-between align-items-end gap-1">
                <span data-photo-featured-control>
                  <button type="button"
                          class="media-photo-feature-button btn btn-sm btn-warning border py-0 px-1 fw-semibold"
                          title="Definir como destaque"
                          data-action="photo-upload#setFeatured">
                    <i class="bi bi-star"></i>
                  </button>
                </span>
                <button type="button" class="media-photo-drag-handle btn btn-sm btn-light border py-0 px-1" title="Arrastar foto">
                  <i class="bi bi-grip-vertical"></i>
                </button>
              </div>
            </div>
          </div>
        `
        this.previewContainerTarget.appendChild(imgContainer)
        this.updateOrder()
        this.refreshPhotoBadges()
      }

      reader.readAsDataURL(file)
    })
  }
}
