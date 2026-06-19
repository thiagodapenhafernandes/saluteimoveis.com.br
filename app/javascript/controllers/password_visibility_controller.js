import { Controller } from "@hotwired/stimulus"

// Alterna a visibilidade de um campo de senha (mostrar/ocultar).
// Uso:
//   <div data-controller="password-visibility">
//     <input type="password" data-password-visibility-target="input">
//     <button data-action="password-visibility#toggle" data-password-visibility-target="button">
//       <i class="bi bi-eye" data-password-visibility-target="icon"></i>
//     </button>
//   </div>
export default class extends Controller {
  static targets = ["input", "icon", "button"]

  toggle() {
    if (!this.hasInputTarget) return

    const reveal = this.inputTarget.type === "password"
    this.inputTarget.type = reveal ? "text" : "password"

    if (this.hasIconTarget) {
      this.iconTarget.classList.toggle("bi-eye", !reveal)
      this.iconTarget.classList.toggle("bi-eye-slash", reveal)
    }

    if (this.hasButtonTarget) {
      const label = reveal ? "Ocultar senha" : "Mostrar senha"
      this.buttonTarget.setAttribute("aria-label", label)
      this.buttonTarget.setAttribute("title", label)
    }
  }
}
