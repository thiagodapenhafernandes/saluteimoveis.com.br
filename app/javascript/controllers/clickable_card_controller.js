import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static values = { url: String }

  connect() {
    this.isDragging = false
    this.dragStartTime = null

    // Detecta início de drag/swipe
    this.element.addEventListener('mousedown', this.handleMouseDown.bind(this))
    this.element.addEventListener('touchstart', this.handleTouchStart.bind(this))

    // Detecta fim de drag
    this.element.addEventListener('mouseup', this.handleMouseUp.bind(this))
    this.element.addEventListener('touchend', this.handleTouchEnd.bind(this))

    // Detecta movimento (indica drag)
    this.element.addEventListener('mousemove', this.handleMouseMove.bind(this))
    this.element.addEventListener('touchmove', this.handleTouchMove.bind(this))

    // Adiciona evento de clique no card
    this.element.addEventListener('click', this.handleClick.bind(this))
  }

  disconnect() {
    this.element.removeEventListener('click', this.handleClick.bind(this))
  }

  handleMouseDown(event) {
    this.isDragging = false
    this.dragStartTime = Date.now()
    this.startX = event.clientX
    this.startY = event.clientY
  }

  handleTouchStart(event) {
    this.isDragging = false
    this.dragStartTime = Date.now()
    const touch = event.touches[0]
    this.startX = touch.clientX
    this.startY = touch.clientY
  }

  handleMouseMove(event) {
    if (this.dragStartTime) {
      const deltaX = Math.abs(event.clientX - this.startX)
      const deltaY = Math.abs(event.clientY - this.startY)

      // Se moveu mais de 5px, considera como drag
      if (deltaX > 5 || deltaY > 5) {
        this.isDragging = true
      }
    }
  }

  handleTouchMove(event) {
    if (this.dragStartTime) {
      const touch = event.touches[0]
      const deltaX = Math.abs(touch.clientX - this.startX)
      const deltaY = Math.abs(touch.clientY - this.startY)

      // Se moveu mais de 5px, considera como drag
      if (deltaX > 5 || deltaY > 5) {
        this.isDragging = true
      }
    }
  }

  handleMouseUp() {
    this.dragStartTime = null
  }

  handleTouchEnd() {
    this.dragStartTime = null
  }

  handleClick(event) {
    // Se foi um drag/swipe, não navega
    if (this.isDragging) {
      this.isDragging = false
      return
    }

    // Se clicou em botões do Swiper, não navega
    const target = event.target
    if (target.closest('.swiper-button-next') ||
      target.closest('.swiper-button-prev') ||
      target.closest('.swiper-pagination')) {
      return
    }

    // Navega para a página do imóvel
    if (this.urlValue) {
      Turbo.visit(this.urlValue)
    }
  }
}
