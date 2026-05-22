import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "propertyId", "leadType", "origin", "shareToken", "name", "phone", "email", "submitButton"]
  static values = {
    enabled: Boolean,
    shareToken: String
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

  async open(event) {
    event.preventDefault()
    event.stopPropagation()

    // Get data from the trigger element
    const trigger = event.currentTarget
    const propertyId = trigger.dataset.propertyId
    const propertyTitle = trigger.dataset.propertyTitle || ""
    const propertyCode = trigger.dataset.propertyCode || ""
    const message = trigger.dataset.whatsappMessage || `Olá, gostaria de mais informações sobre o imóvel ${propertyTitle} (Cód: ${propertyCode})`
    const leadOrigin = trigger.dataset.leadOrigin || ""
    const shareToken = trigger.dataset.shareToken || this.shareTokenValue || ""

    // Store message for redirect
    this.whatsappMessage = message

    const routing = await this.fetchWhatsappRouting(propertyId, message)
    if (routing && routing.capture_required === false && routing.whatsapp_url) {
      window.location.href = routing.whatsapp_url
      return
    }

    // Set hidden fields
    if (this.hasPropertyIdTarget) this.propertyIdTarget.value = propertyId
    if (this.hasLeadTypeTarget) this.leadTypeTarget.value = 'whatsapp_click' // Default
    if (this.hasOriginTarget) this.originTarget.value = leadOrigin
    if (this.hasShareTokenTarget) this.shareTokenTarget.value = shareToken

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

  async submit(event) {
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

    const result = await this.sendLeadData({
      name,
      phone: phoneWithMask,
      email,
      property_id: this.propertyIdTarget.value,
      origin: this.hasOriginTarget ? this.originTarget.value : "",
      share_token: this.hasShareTokenTarget ? this.shareTokenTarget.value : "",
      whatsapp_message: this.whatsappMessage
    })

    const whatsappUrl = result?.whatsapp_url || await this.fallbackWhatsappUrl()

    // Redirect to WhatsApp
    window.location.href = whatsappUrl

    // Close modal
    this.close()

    // Optional: Reset form
    event.target.reset()
  }

  async sendLeadData(data) {
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
        return response.json()
      } else {
        console.warn("Failed to capture lead on backend")
        return null
      }
    }).catch(error => {
      console.error("Error capturing lead:", error)
      return null
    })
  }

  fetchWhatsappRouting(propertyId, message) {
    const params = new URLSearchParams()
    if (propertyId) params.set("property_id", propertyId)
    if (message) params.set("message", message)

    return fetch(`/leads/whatsapp_url?${params.toString()}`, {
      headers: { "Accept": "application/json" }
    }).then(response => {
      if (response.ok) return response.json()
      return null
    }).catch(error => {
      console.error("Error fetching WhatsApp routing:", error)
      return null
    })
  }

  async fallbackWhatsappUrl() {
    const routing = await this.fetchWhatsappRouting(this.hasPropertyIdTarget ? this.propertyIdTarget.value : "", this.whatsappMessage)
    return routing?.whatsapp_url || `https://wa.me/554733111067?text=${encodeURIComponent(this.whatsappMessage || "")}`
  }
}
