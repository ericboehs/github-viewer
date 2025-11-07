import { Controller } from "@hotwired/stimulus"

// Stimulus controller for issues search input
export default class extends Controller {
  // Move cursor to end of input when focused (instead of selecting all text)
  moveCursorToEnd(event) {
    const input = event.target
    const length = input.value.length

    // Move cursor to end after a brief delay to override browser's default select-all behavior
    setTimeout(() => {
      input.setSelectionRange(length, length)
    }, 0)
  }
}
