import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "propertyId", "leadType", "name", "phone", "email", "submitButton"]
  static values = {
    enabled: Boolean
  }

  connect() {
    // Close on escape key
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && this.hasModalTarget && !this.modalTarget.classList.contains('hidden')) {
        this.close()
      }
    })
  }

  applyMask(event) {
    let value = event.target.value.replace(/\D/g, "")
    value = value.replace(/^(\d{2})(\d)/g, "($1) $2")
    value = value.replace(/(\d)(\d{4})$/, "$1-$2")
    event.target.value = value.substring(0, 15) // Limit length
  }

  open(event) {
    event.preventDefault()
    event.stopPropagation()

    // Get data from the trigger element
    const trigger = event.currentTarget
    const propertyId = trigger.dataset.propertyId
    const propertyTitle = trigger.dataset.propertyTitle || ""
    const propertyCode = trigger.dataset.propertyCode || ""
    const message = trigger.dataset.whatsappMessage || `Olá, gostaria de mais informações sobre o imóvel ${propertyTitle} (Cód: ${propertyCode})`

    // Store message for redirect
    this.whatsappMessage = message

    // Set hidden fields
    if (this.hasPropertyIdTarget) this.propertyIdTarget.value = propertyId
    if (this.hasLeadTypeTarget) this.leadTypeTarget.value = 'whatsapp_click' // Default

    // Show modal
    this.modalTarget.classList.remove('hidden')
    document.body.style.overflow = 'hidden' // Prevent scrolling

    // Focus name input
    setTimeout(() => {
      if (this.hasNameTarget) this.nameTarget.focus()
    }, 100)
  }

  close() {
    this.modalTarget.classList.add('hidden')
    document.body.style.overflow = ''
  }

  submit(event) {
    event.preventDefault()

    const name = this.nameTarget.value.trim()
    const phoneWithMask = this.phoneTarget.value
    const phone = phoneWithMask.replace(/\D/g, "")
    const email = this.hasEmailTarget ? this.emailTarget.value : ""

    // Validation
    if (name.length < 3) {
      alert("Por favor, informe seu nome completo.")
      this.nameTarget.focus()
      return
    }

    if (phone.length < 10 || phone.length > 11) {
      alert("Por favor, informe um número de WhatsApp válido com DDD.")
      this.phoneTarget.focus()
      return
    }

    // Submit logic
    // We send payload to Rails controller via fetch which then handles the Webhook
    // But to respect the flow, we will first capture on backend then redirect.
    // If backend fails, we redirect anyway to not block the user.

    this.sendLeadData({ name, phone: phoneWithMask, email, property_id: this.propertyIdTarget.value })

    // Construct WhatsApp URL
    // Default number if not configured elsewhere - using the one from the views
    const phoneNumber = "554733111067" // This should ideally come from backend config too
    const text = encodeURIComponent(this.whatsappMessage)
    const whatsappUrl = `https://wa.me/${phoneNumber}?text=${text}`

    // Open WhatsApp
    window.open(whatsappUrl, '_blank')

    // Close modal
    this.close()

    // Optional: Reset form
    event.target.reset()
  }

  sendLeadData(data) {
    const csrfToken = document.querySelector("[name='csrf-token']").content

    return fetch('/leads', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken
      },
      body: JSON.stringify({ lead: { ...data, lead_type: 'whatsapp_modal' } })
    }).then(response => {
      if (response.ok) {
        console.log("Lead captured successfully")
      } else {
        console.warn("Failed to capture lead on backend")
      }
    }).catch(error => {
      console.error("Error capturing lead:", error)
    })
  }
}
