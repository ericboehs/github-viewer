import { Controller } from "@hotwired/stimulus"

// Toggles visibility of filter dropdowns on mobile screens
export default class extends Controller {
  static targets = ["mobileFilters", "icon"]

  connect() {
    // Mobile filters start hidden
    if (this.hasMobileFiltersTarget) {
      this.mobileFiltersTarget.classList.add("hidden")
    }
  }

  toggle() {
    if (this.hasMobileFiltersTarget) {
      this.mobileFiltersTarget.classList.toggle("hidden")

      // Rotate the chevron icon
      if (this.hasIconTarget) {
        this.iconTarget.classList.toggle("rotate-180")
      }
    }
  }
}
