import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    eventType: String,
    placement: String,
    label: String,
    targetUrl: String,
    campaignId: Number,
    habitationId: Number,
    component: String,
    conversionEvent: String,
    businessType: String,
    negotiationType: String
  }

  track(event) {
    if (!this.canTrack()) return

    const target = event.currentTarget
    const externalPayload = this.externalPayloadFor(target)
    const payload = new FormData()

    payload.append("event_type", this.valueFor(target, "eventType") || this.eventTypeValue || "campaign_click")
    payload.append("placement", this.valueFor(target, "placement") || this.placementValue || "")
    payload.append("label", this.valueFor(target, "label") || this.labelValue || target.textContent?.trim() || "")
    payload.append("target_url", this.valueFor(target, "targetUrl") || this.targetUrlValue || target.href || "")
    payload.append("page_url", window.location.href)
    payload.append("component", this.valueFor(target, "component") || this.componentValue || "")
    payload.append("conversion_event", externalPayload.conversion_event || "")
    payload.append("business_type", externalPayload.ctwa_business_type || "")
    payload.append("negotiation_type", externalPayload.ctwa_negotiation_type || "")

    const campaignId = this.valueFor(target, "campaignId") || this.campaignIdValue
    const habitationId = this.valueFor(target, "habitationId") || this.habitationIdValue
    if (campaignId) payload.append("marketing_campaign_id", campaignId)
    if (habitationId) payload.append("habitation_id", habitationId)

    this.pushExternalConversion(externalPayload)

    if (navigator.sendBeacon) {
      navigator.sendBeacon("/marketing/events", payload)
      return
    }

    fetch("/marketing/events", {
      method: "POST",
      body: payload,
      credentials: "same-origin",
      keepalive: true
    }).catch(() => {})
  }

  valueFor(element, name) {
    return element.dataset[`marketingTracker${this.capitalize(name)}Value`]
  }

  externalPayloadFor(target) {
    const conversionEvent = this.valueFor(target, "conversionEvent") || target.dataset.conversionEvent || this.conversionEventValue || ""
    const businessType = this.valueFor(target, "businessType") || target.dataset.ctwaBusinessType || this.businessTypeValue || ""
    const negotiationType = this.valueFor(target, "negotiationType") || target.dataset.ctwaNegotiationType || target.dataset.negotiationType || this.negotiationTypeValue || ""

    return {
      event: conversionEvent,
      conversion_event: conversionEvent,
      ctwa_id: target.dataset.ctwaId || "",
      ctwa_business_type: businessType,
      ctwa_negotiation_type: negotiationType,
      property_id: target.dataset.propertyId || this.valueFor(target, "habitationId") || "",
      property_code: target.dataset.propertyCode || "",
      placement: this.valueFor(target, "placement") || this.placementValue || "",
      label: this.valueFor(target, "label") || this.labelValue || target.textContent?.trim() || "",
      page_url: window.location.href,
      target_url: this.valueFor(target, "targetUrl") || this.targetUrlValue || target.href || ""
    }
  }

  pushExternalConversion(payload) {
    if (!payload.conversion_event) return

    window.dataLayer = window.dataLayer || []
    window.dataLayer.push(payload)
  }

  capitalize(value) {
    return value.charAt(0).toUpperCase() + value.slice(1)
  }

  canTrack() {
    return window.SaluteLgpdConsent?.accepted?.() === true
  }
}
