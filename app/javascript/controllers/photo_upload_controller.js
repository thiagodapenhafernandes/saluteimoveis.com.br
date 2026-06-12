import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Connects to data-controller="photo-upload"
export default class extends Controller {
  static targets = [
    "input",
    "orderInput",
    "apiOrderInput",
    "hiddenPhotoIdsInput",
    "hiddenPictureUrlsInput",
    "removePhotoIdsInput",
    "removePictureIndicesInput",
    "uploadLimitFeedback",
    "previewContainer",
    "scrollContainer",
    "dirtyStatus",
    "saveButton",
    "saveButtonLabel"
  ]

  static maxUploadBytes = 250 * 1024 * 1024

  connect() {
    this.selectedNewFiles = []
    this.newFileIdCounter = 0
    this.directUploadCards = new Map()
    this.photoStateDirty = false
    this.dragScrollDirection = 0
    this.dragScrollSpeed = 0
    this.dragScrollFrame = null
    this.boundHandleDragOver = this.handleDragOver.bind(this)
    this.boundHandleDrop = this.handleDrop.bind(this)
    this.boundHandleDragLeave = this.handleDragLeave.bind(this)
    this.boundValidateSubmit = this.validateSubmit.bind(this)
    this.boundHandleAutoScrollPointer = this.handleAutoScrollPointer.bind(this)
    this.boundDirectUploadInitialize = this.directUploadInitialize.bind(this)
    this.boundDirectUploadProgress = this.directUploadProgress.bind(this)
    this.boundDirectUploadEnd = this.directUploadEnd.bind(this)
    this.boundDirectUploadError = this.directUploadError.bind(this)
    this.form = this.element.closest('form')

    this.initSortable()
    this.captureOriginalPhotoState()
    this.updateDirtyState(false)

    // Drag and Drop
    this.element.addEventListener('dragover', this.boundHandleDragOver)
    this.element.addEventListener('drop', this.boundHandleDrop)
    this.element.addEventListener('dragleave', this.boundHandleDragLeave)
    if (this.form) this.form.addEventListener('submit', this.boundValidateSubmit, true)
    if (this.hasInputTarget) {
      this.inputTarget.addEventListener('direct-upload:initialize', this.boundDirectUploadInitialize)
      this.inputTarget.addEventListener('direct-upload:progress', this.boundDirectUploadProgress)
      this.inputTarget.addEventListener('direct-upload:end', this.boundDirectUploadEnd)
      this.inputTarget.addEventListener('direct-upload:error', this.boundDirectUploadError)
    }
  }

  disconnect() {
    if (this.sortable) this.sortable.destroy()
    this.stopAutoScroll()
    this.element.removeEventListener('dragover', this.boundHandleDragOver)
    this.element.removeEventListener('drop', this.boundHandleDrop)
    this.element.removeEventListener('dragleave', this.boundHandleDragLeave)
    if (this.form) this.form.removeEventListener('submit', this.boundValidateSubmit, true)
    if (this.hasInputTarget) {
      this.inputTarget.removeEventListener('direct-upload:initialize', this.boundDirectUploadInitialize)
      this.inputTarget.removeEventListener('direct-upload:progress', this.boundDirectUploadProgress)
      this.inputTarget.removeEventListener('direct-upload:end', this.boundDirectUploadEnd)
      this.inputTarget.removeEventListener('direct-upload:error', this.boundDirectUploadError)
    }
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
      scroll: true,
      bubbleScroll: true,
      forceAutoScrollFallback: true,
      scrollSensitivity: 90,
      scrollSpeed: 18,
      ghostClass: 'sortable-ghost',
      handle: '.media-photo-drag-handle',
      draggable: '.draggable-item',
      onStart: () => {
        this.startAutoScroll()
      },
      onMove: (evt) => {
        this.handleAutoScrollPointer(evt.originalEvent)
        return true
      },
      onEnd: (evt) => {
        this.stopAutoScroll()
        this.syncNewFilesFromDom()
        this.updateOrder()
        this.refreshPhotoBadges()
        if (evt.oldIndex !== evt.newIndex) this.markDirty()
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
    this.syncNewFilesFromDom()
    this.updateOrder()
    this.refreshPhotoBadges()
    this.markDirty()
  }

  removeNew(event) {
    event.preventDefault()
    event.stopPropagation()

    const item = event.currentTarget.closest('.new-photo-preview')
    if (!item) return

    const fileId = item.dataset.newFileId
    this.selectedNewFiles = this.selectedNewFiles.filter(entry => entry.id !== fileId)
    item.remove()

    this.syncInputFilesFromState()
    this.clearUploadLimitFeedback()
    this.updateOrder()
    this.refreshPhotoBadges()
    this.markDirty()
  }

  removeAttached(event) {
    event.preventDefault()
    event.stopPropagation()

    const item = event.currentTarget.closest('.attached-photo-item')
    if (!item || !item.dataset.id) return
    if (!this.hasRemovePhotoIdsInputTarget) return

    this.appendHiddenListValue(this.removePhotoIdsInputTarget, item.dataset.id)
    item.classList.add('d-none')
    item.remove()

    this.updateOrder()
    this.refreshPhotoBadges()
    this.markDirty()
  }

  removeApiPicture(event) {
    event.preventDefault()
    event.stopPropagation()

    const item = event.currentTarget.closest('.api-picture-item')
    if (!item || !item.dataset.apiIndex) return
    if (!this.hasRemovePictureIndicesInputTarget) return

    this.appendHiddenListValue(this.removePictureIndicesInputTarget, item.dataset.apiIndex)
    item.classList.add('d-none')
    item.remove()

    this.updateOrder()
    this.refreshPhotoBadges()
    this.markDirty()
  }

  toggleSiteVisibility(event) {
    event.preventDefault()
    event.stopPropagation()

    const button = event.currentTarget
    const tile = button.closest('.media-photo-tile')
    if (!tile) return

    const hidden = tile.dataset.siteHidden !== "true"
    tile.dataset.siteHidden = hidden ? "true" : "false"
    tile.classList.toggle('is-site-hidden', hidden)

    if (button.dataset.photoId && this.hasHiddenPhotoIdsInputTarget) {
      this.toggleHiddenListValue(this.hiddenPhotoIdsInputTarget, button.dataset.photoId, hidden)
    }

    if (button.dataset.pictureUrl && this.hasHiddenPictureUrlsInputTarget) {
      this.toggleHiddenListValue(this.hiddenPictureUrlsInputTarget, button.dataset.pictureUrl, hidden)
    }

    this.setSiteToggleButton(button, hidden)
    this.markDirty()
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
    const files = Array.from(event.target.files || [])
    const existingFileKeys = new Set(this.selectedNewFiles.map(entry => this.fileKey(entry.file)))
    const newFileEntries = files.filter(file => {
      const key = this.fileKey(file)
      if (existingFileKeys.has(key)) return false

      existingFileKeys.add(key)
      return true
    }).map(file => ({
      id: this.nextNewFileId(),
      file
    }))

    const nextUploadBytes = this.uploadBytesFor(this.selectedNewFiles.concat(newFileEntries))
    if (nextUploadBytes > this.constructor.maxUploadBytes) {
      this.showUploadLimitFeedback(nextUploadBytes)
      this.syncInputFilesFromState()
      return
    }

    this.clearUploadLimitFeedback()
    this.selectedNewFiles = this.selectedNewFiles.concat(newFileEntries)

    if (newFileEntries.length === 0) {
      this.syncInputFilesFromState()
      this.updateOrder()
      this.refreshPhotoBadges()
      return
    }

    newFileEntries.forEach(fileEntry => {
      const file = fileEntry.file
      const imgContainer = document.createElement("div")
      const previewUrl = URL.createObjectURL(file)
      const fileKey = this.fileKey(file)

      // Match standard column classes and add draggable-item
      imgContainer.classList.add("col-6", "col-md-3", "col-lg-2", "draggable-item", "new-photo-preview")
      imgContainer.dataset.newFileId = fileEntry.id
      imgContainer.dataset.fileKey = fileKey

      imgContainer.innerHTML = `
        <div class="position-relative ratio ratio-1x1 group-hover media-photo-tile">
          <img src="${previewUrl}" class="rounded border object-fit-cover w-100 h-100" alt="${this.escapeHtml(file.name)}">
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
              <span class="d-flex align-items-center gap-1">
                <button type="button"
                        class="btn btn-sm btn-danger border py-0 px-1"
                        title="Remover foto selecionada"
                        data-action="photo-upload#removeNew">
                  <i class="bi bi-trash"></i>
                </button>
                <button type="button" class="media-photo-drag-handle btn btn-sm btn-light border py-0 px-1" title="Arrastar foto">
                  <i class="bi bi-grip-vertical"></i>
                </button>
              </span>
            </div>
          </div>
          <div class="media-photo-upload-progress" aria-hidden="true">
            <div class="media-photo-upload-progress-bar" style="width: 0%"></div>
          </div>
        </div>
      `
      this.previewContainerTarget.appendChild(imgContainer)
    })

    this.syncInputFilesFromState()
    this.updateOrder()
    this.refreshPhotoBadges()
    this.markDirty()
  }

  validateSubmit(event) {
    const uploadBytes = this.uploadBytesFor(this.selectedNewFiles)
    if (uploadBytes <= this.constructor.maxUploadBytes) return

    event.preventDefault()
    event.stopImmediatePropagation()
    this.showUploadLimitFeedback(uploadBytes)
  }

  preparePhotoSubmit(event) {
    if (this.photoStateDirty || this.selectedNewFiles.length > 0) {
      this.setSaveButtonLoading()
      return
    }

    event.preventDefault()
    event.stopPropagation()
    this.showDirtyStatus("Nenhuma alteração em fotos para salvar.")
  }

  startAutoScroll() {
    if (!this.hasScrollContainerTarget) return

    this.scrollContainerTarget.classList.add("is-photo-dragging")
    document.addEventListener("dragover", this.boundHandleAutoScrollPointer, true)
    document.addEventListener("mousemove", this.boundHandleAutoScrollPointer, true)
    document.addEventListener("touchmove", this.boundHandleAutoScrollPointer, true)
  }

  stopAutoScroll() {
    if (this.hasScrollContainerTarget) this.scrollContainerTarget.classList.remove("is-photo-dragging")

    document.removeEventListener("dragover", this.boundHandleAutoScrollPointer, true)
    document.removeEventListener("mousemove", this.boundHandleAutoScrollPointer, true)
    document.removeEventListener("touchmove", this.boundHandleAutoScrollPointer, true)
    this.dragScrollDirection = 0
    this.dragScrollSpeed = 0

    if (this.dragScrollFrame) {
      cancelAnimationFrame(this.dragScrollFrame)
      this.dragScrollFrame = null
    }
  }

  handleAutoScrollPointer(event) {
    if (!this.hasScrollContainerTarget) return

    const pointerY = this.pointerClientY(event)
    if (pointerY === null) return

    const rect = this.scrollContainerTarget.getBoundingClientRect()
    const threshold = Math.min(120, Math.max(70, rect.height * 0.18))
    const topDistance = pointerY - rect.top
    const bottomDistance = rect.bottom - pointerY

    if (topDistance >= 0 && topDistance < threshold) {
      this.queueAutoScroll(-1, 1 - (topDistance / threshold))
      return
    }

    if (bottomDistance >= 0 && bottomDistance < threshold) {
      this.queueAutoScroll(1, 1 - (bottomDistance / threshold))
      return
    }

    this.dragScrollDirection = 0
    this.dragScrollSpeed = 0
  }

  pointerClientY(event) {
    if (!event) return null
    if (event.touches && event.touches[0]) return event.touches[0].clientY
    if (event.changedTouches && event.changedTouches[0]) return event.changedTouches[0].clientY
    return Number.isFinite(event.clientY) ? event.clientY : null
  }

  queueAutoScroll(direction, intensity) {
    this.dragScrollDirection = direction
    this.dragScrollSpeed = Math.max(8, Math.round(36 * Math.max(0.2, intensity)))

    if (!this.dragScrollFrame) this.dragScrollFrame = requestAnimationFrame(() => this.performAutoScroll())
  }

  performAutoScroll() {
    this.dragScrollFrame = null
    if (!this.hasScrollContainerTarget || this.dragScrollDirection === 0) return

    const container = this.scrollContainerTarget
    const previousTop = container.scrollTop
    container.scrollTop += this.dragScrollDirection * this.dragScrollSpeed

    if (container.scrollTop === previousTop) {
      window.scrollBy({ top: this.dragScrollDirection * this.dragScrollSpeed, behavior: "auto" })
    }

    this.dragScrollFrame = requestAnimationFrame(() => this.performAutoScroll())
  }

  directUploadInitialize(event) {
    const card = this.cardForDirectUploadEvent(event)
    if (!card) return

    const id = event?.detail?.id
    if (id) {
      card.dataset.directUploadId = id
      this.directUploadCards.set(id, card)
    }

    this.setCardUploadProgress(card, 1, "uploading")
  }

  directUploadProgress(event) {
    const card = this.cardForDirectUploadEvent(event)
    if (!card) return

    const percent = Math.max(1, Math.min(99, Math.round(Number(event?.detail?.progress || 0))))
    this.setCardUploadProgress(card, percent, "uploading")
  }

  directUploadEnd(event) {
    const card = this.cardForDirectUploadEvent(event)
    if (!card) return

    this.setCardUploadProgress(card, 100, "uploaded")
  }

  directUploadError(event) {
    const card = this.cardForDirectUploadEvent(event)
    if (!card) return

    this.setCardUploadProgress(card, 100, "error")
  }

  cardForDirectUploadEvent(event) {
    const id = event?.detail?.id
    if (id && this.directUploadCards.has(id)) return this.directUploadCards.get(id)

    const file = event?.detail?.file
    if (!file || !this.hasPreviewContainerTarget) return null

    const fileKey = this.fileKey(file)
    const card = Array.from(this.previewContainerTarget.querySelectorAll(".new-photo-preview"))
      .find(item => item.dataset.fileKey === fileKey && (!item.dataset.directUploadId || item.dataset.directUploadId === id))

    if (id && card) {
      card.dataset.directUploadId = id
      this.directUploadCards.set(id, card)
    }

    return card
  }

  setCardUploadProgress(card, percent, state) {
    const tile = card.querySelector(".media-photo-tile")
    const bar = card.querySelector(".media-photo-upload-progress-bar")
    if (!tile || !bar) return

    tile.classList.toggle("is-uploading", state === "uploading")
    tile.classList.toggle("is-uploaded", state === "uploaded")
    tile.classList.toggle("is-upload-error", state === "error")
    bar.style.width = `${Math.max(0, Math.min(100, percent))}%`
  }

  captureOriginalPhotoState() {
    this.originalPhotoState = this.currentPhotoState()
  }

  currentPhotoState() {
    return [
      this.hasOrderInputTarget ? this.orderInputTarget.value : "",
      this.hasApiOrderInputTarget ? this.apiOrderInputTarget.value : "",
      this.hasHiddenPhotoIdsInputTarget ? this.hiddenPhotoIdsInputTarget.value : "",
      this.hasHiddenPictureUrlsInputTarget ? this.hiddenPictureUrlsInputTarget.value : "",
      this.hasRemovePhotoIdsInputTarget ? this.removePhotoIdsInputTarget.value : "",
      this.hasRemovePictureIndicesInputTarget ? this.removePictureIndicesInputTarget.value : "",
      this.selectedNewFiles.map(entry => this.fileKey(entry.file)).join("|")
    ].join("::")
  }

  markDirty() {
    this.updateDirtyState(this.currentPhotoState() !== this.originalPhotoState)
  }

  updateDirtyState(dirty) {
    this.photoStateDirty = dirty
    if (this.hasSaveButtonTarget) {
      this.saveButtonTarget.disabled = !dirty
      this.saveButtonTarget.classList.toggle("disabled", !dirty)
    }

    if (this.hasDirtyStatusTarget) {
      if (dirty) {
        this.showDirtyStatus("Alterações em fotos pendentes")
      } else {
        this.dirtyStatusTarget.classList.add("d-none")
      }
    }
  }

  showDirtyStatus(message) {
    if (!this.hasDirtyStatusTarget) return

    this.dirtyStatusTarget.textContent = message
    this.dirtyStatusTarget.classList.remove("d-none")
  }

  setSaveButtonLoading() {
    if (!this.hasSaveButtonTarget) return

    this.saveButtonTarget.disabled = true
    this.saveButtonTarget.classList.add("disabled")
    if (this.hasSaveButtonLabelTarget) this.saveButtonLabelTarget.textContent = "Salvando fotos..."
  }

  syncNewFilesFromDom() {
    if (!this.hasPreviewContainerTarget || this.selectedNewFiles.length === 0) return

    const byId = new Map(this.selectedNewFiles.map(entry => [entry.id, entry]))
    const orderedIds = Array.from(this.previewContainerTarget.querySelectorAll('.new-photo-preview'))
      .map(el => el.dataset.newFileId)
      .filter(id => byId.has(id))

    this.selectedNewFiles = orderedIds.map(id => byId.get(id))
    this.syncInputFilesFromState()
  }

  syncInputFilesFromState() {
    if (!this.hasInputTarget || typeof DataTransfer === "undefined") return

    const dataTransfer = new DataTransfer()
    this.selectedNewFiles.forEach(entry => dataTransfer.items.add(entry.file))
    this.inputTarget.files = dataTransfer.files
  }

  appendHiddenListValue(input, value) {
    if (!input || !value) return

    const values = input.value
      .split(',')
      .map(item => item.trim())
      .filter(Boolean)

    if (!values.includes(value)) values.push(value)
    input.value = values.join(',')
  }

  toggleHiddenListValue(input, value, hidden) {
    if (!input || !value) return

    const values = input.value
      .split(',')
      .map(item => item.trim())
      .filter(Boolean)

    const nextValues = hidden
      ? Array.from(new Set(values.concat(value)))
      : values.filter(item => item !== value)

    input.value = nextValues.join(',')
  }

  setSiteToggleButton(button, hidden) {
    button.classList.toggle('btn-success', !hidden)
    button.classList.toggle('btn-secondary', hidden)
    button.title = hidden ? 'Foto interna, fora do site' : 'Foto publicada no site'

    const icon = button.querySelector('i')
    if (icon) {
      icon.classList.toggle('bi-globe2', !hidden)
      icon.classList.toggle('bi-eye-slash', hidden)
    }

    const label = button.querySelector('span')
    if (label) label.textContent = hidden ? 'Interna' : 'Site'
  }

  nextNewFileId() {
    this.newFileIdCounter += 1
    return `new-photo-${Date.now()}-${this.newFileIdCounter}`
  }

  fileKey(file) {
    return [file.name, file.size, file.lastModified].join(':')
  }

  uploadBytesFor(entries) {
    return entries.reduce((total, entry) => total + Number(entry.file?.size || 0), 0)
  }

  showUploadLimitFeedback(totalBytes = this.uploadBytesFor(this.selectedNewFiles)) {
    const message = `As novas fotos selecionadas somam ${this.formatBytes(totalBytes)}. Envie no máximo ${this.formatBytes(this.constructor.maxUploadBytes)} por vez.`
    this.showMediaTab()

    if (this.hasUploadLimitFeedbackTarget) {
      this.uploadLimitFeedbackTarget.textContent = message
      this.uploadLimitFeedbackTarget.classList.remove('d-none')
    } else {
      window.alert(message)
    }

    if (this.hasInputTarget) this.inputTarget.value = ""
    this.element.scrollIntoView({ behavior: "smooth", block: "center" })
  }

  showMediaTab() {
    const panel = this.element.closest(".tab-pane")
    if (!panel?.id) return

    const tabButton = document.querySelector(`[data-bs-target="#${CSS.escape(panel.id)}"]`)
    const bootstrapElement = window.bootstrap || (typeof bootstrap !== "undefined" ? bootstrap : null)

    if (tabButton && bootstrapElement?.Tab) {
      bootstrapElement.Tab.getOrCreateInstance(tabButton).show()
      return
    }

    if (tabButton) tabButton.click()
  }

  clearUploadLimitFeedback() {
    if (!this.hasUploadLimitFeedbackTarget) return

    this.uploadLimitFeedbackTarget.textContent = ""
    this.uploadLimitFeedbackTarget.classList.add('d-none')
  }

  formatBytes(bytes) {
    return `${(bytes / (1024 * 1024)).toLocaleString("pt-BR", { maximumFractionDigits: 1 })} MB`
  }

  escapeHtml(value) {
    const span = document.createElement("span")
    span.textContent = value || ""
    return span.innerHTML
  }
}
