import { Controller } from "@hotwired/stimulus"

// Mostra apenas o campo de valor compatível com o status comercial, para evitar
// preencher o campo errado (venda x locação). Status de venda mostra "Venda",
// status de locação mostra "Aluguel", e status ambíguos (pendente/suspenso/vazio)
// mostram os dois. Os campos continuam no DOM (apenas ocultos), então valores já
// preenchidos seguem sendo enviados no submit.
export default class extends Controller {
  static targets = ["statusSelect", "saleField", "rentField"]

  connect() {
    this.toggle()
  }

  toggle() {
    const status = this.hasStatusSelectTarget ? this.statusSelectTarget.value.toString() : ""
    const norm = status.normalize("NFD").replace(/\p{Diacritic}/gu, "").toLowerCase()

    const rental = /(alug|diaria|locac)/.test(norm)
    const sale = /(venda|vendid|lancamento)/.test(norm)
    const ambiguous = !rental && !sale

    const showSale = sale || ambiguous
    const showRent = rental || ambiguous

    this.saleFieldTargets.forEach((el) => { el.hidden = !showSale })
    this.rentFieldTargets.forEach((el) => { el.hidden = !showRent })
  }
}
