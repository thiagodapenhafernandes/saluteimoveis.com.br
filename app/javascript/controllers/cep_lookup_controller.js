import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="cep-lookup"
export default class extends Controller {
  static targets = ["cep", "address", "neighborhood", "city"]

  connect() {
    console.log("CEP Lookup Controller connected")
  }

  lookup(event) {
    if (event) event.preventDefault()
    const cep = this.cepTarget.value.replace(/\D/g, '')

    if (cep.length === 8) {
      this.fetchAddress(cep)
    } else if (event.type === 'click') {
      this.showError("CEP inválido")
    }
  }

  async fetchAddress(cep) {
    try {
      this.setLoading(true)
      const response = await fetch(`https://viacep.com.br/ws/${cep}/json/`)
      const data = await response.json()

      if (data.erro) {
        this.showError("CEP não encontrado")
      } else {
        this.fillFields(data)
      }
    } catch (error) {
      console.error("Erro ao buscar CEP:", error)
      this.showError("Erro na conexão")
    } finally {
      this.setLoading(false)
    }
  }

  fillFields(data) {
    if (this.hasAddressTarget) this.addressTarget.value = data.logradouro
    if (this.hasNeighborhoodTarget) this.neighborhoodTarget.value = data.bairro
    if (this.hasCityTarget) this.cityTarget.value = data.localidade

    // Auto-focus on number if address is filled
    if (data.logradouro && this.hasAddressTarget) {
      // In Development we don't have a separate number field yet, 
      // but if we did, we could focus it.
    }
  }

  setLoading(isLoading) {
    if (isLoading) {
      this.cepTarget.classList.add("is-loading")
      // You could add a spinner here if needed
    } else {
      this.cepTarget.classList.remove("is-loading")
    }
  }

  showError(message) {
    // Basic error handling - could be improved with Toast or similar
    console.warn(message)
  }
}
