import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["cep", "logradouro", "bairro", "cidade", "uf", "tipo", "numero", "complemento"]

  connect() {
    this.lastSearchedCep = ""
  }

  async search(event) {
    // If triggered by blur and value hasn't changed or is empty, ignore
    if (event.type === 'blur') {
      if (this.cepTarget.value === this.lastSearchedCep || this.cepTarget.value === "") return
    } else {
      // If click, prevent default form submission
      event.preventDefault()
    }

    const rawCep = this.cepTarget.value
    const cep = rawCep.replace(/\D/g, '')

    if (cep.length !== 8) return

    this.lastSearchedCep = rawCep

    // UI Feedback
    const btn = this.element.querySelector('button[data-action*="cep-search#search"]')
    let originalIcon = ""

    if (btn) {
      originalIcon = btn.innerHTML
      btn.innerHTML = '<span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span>'
      btn.disabled = true
    }

    // Add loading class to input
    this.cepTarget.classList.add('opacity-50')

    try {
      const response = await fetch(`https://brasilapi.com.br/api/cep/v2/${cep}`)

      if (!response.ok) throw new Error('CEP não encontrado')

      const data = await response.json()

      this.populateForm(data)

      // Visual success feedback
      this.cepTarget.classList.remove('is-invalid')
      this.cepTarget.classList.add('is-valid')
      setTimeout(() => this.cepTarget.classList.remove('is-valid'), 2000)

    } catch (error) {
      console.error(error)
      this.cepTarget.classList.add('is-invalid')
      // Optional: Clean invalid class on input change
    } finally {
      if (btn) {
        btn.innerHTML = originalIcon
        btn.disabled = false
      }
      this.cepTarget.classList.remove('opacity-50')
    }
  }

  populateForm(data) {
    if (!data.street) return

    // 1. UF
    if (this.hasUfTarget) {
      this.ufTarget.value = data.state
      this.triggerChange(this.ufTarget)
    }

    // 2. Cidade (TomSelect)
    if (this.hasCidadeTarget) {
      this.setTomSelectValue(this.cidadeTarget, data.city)
    }

    // 3. Bairro (TomSelect)
    if (this.hasBairroTarget) {
      this.setTomSelectValue(this.bairroTarget, data.neighborhood)
    }

    // 4. Logradouro & Tipo
    // Try to split Street Type from Name
    let streetName = data.street
    let matchedType = false

    if (this.hasTipoTarget) {
      const streetLower = data.street.toLowerCase()
      // Sort options by length desc to match "Avenida" before "Av" if present
      const options = Array.from(this.tipoTarget.options)

      for (const opt of options) {
        const typeText = opt.text
        if (typeText && streetLower.startsWith(typeText.toLowerCase() + " ")) {
          this.tipoTarget.value = opt.value
          streetName = data.street.substring(typeText.length).trim()
          matchedType = true
          this.triggerChange(this.tipoTarget)
          break
        }
      }
    }

    if (this.hasLogradouroTarget) {
      this.logradouroTarget.value = streetName
    }

    // 5. Focus Number
    if (this.hasNumeroTarget) {
      setTimeout(() => this.numeroTarget.focus(), 100)
    }
  }

  setTomSelectValue(element, value) {
    if (!value) return

    // Check for TomSelect instance
    let ts = element.tomselect

    if (ts) {
      // TomSelect doesn't auto-add option if create is true programmatically usually, 
      // we must add it if it doesn't exist.
      // Check if value exists in options (check keys or text)
      // TomSelect options are stored in ts.options = { value: {text, value} }

      // We need to find if there is an option with this text (case insensitive?)
      // BrasilAPI returns standardized case.

      // Let's try to find an existing option by text to get its value
      let existingValue = null
      Object.values(ts.options).forEach(opt => {
        if (opt.text.toLowerCase() === value.toLowerCase()) {
          existingValue = opt.value
        }
      })

      if (existingValue) {
        ts.setValue(existingValue)
      } else {
        // Create new option
        ts.addOption({ value: value, text: value })
        ts.setValue(value)
      }
    } else {
      // Fallback for native select
      element.value = value
    }
  }

  triggerChange(element) {
    const event = new Event('change', { bubbles: true })
    element.dispatchEvent(event)
  }
}
