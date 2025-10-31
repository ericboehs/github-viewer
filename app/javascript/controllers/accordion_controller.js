import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "form"]
  static values = { open: Boolean }

  showForm() {
    // Hide button, show form
    this.buttonTarget.style.display = "none"
    this.formTarget.style.display = "block"
  }

  hideForm() {
    // Show button, hide form
    this.buttonTarget.style.display = "block"
    this.formTarget.style.display = "none"
  }
}
