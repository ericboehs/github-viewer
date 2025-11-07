import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["issueCard", "navigableItem", "searchInput", "modal"]
  static outlets = ["filter-dropdown"]
  static values = {
    navigableTarget: { type: String, default: "navigableItem" },
    linkSelector: { type: String, default: "a" }
  }

  connect() {
    this.currentFocusIndex = -1
    this.handleKeydown = this.handleKeydown.bind(this)
    this.handleFocusIn = this.handleFocusIn.bind(this)
    document.addEventListener("keydown", this.handleKeydown)
    document.addEventListener("focusin", this.handleFocusIn)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown)
    document.removeEventListener("focusin", this.handleFocusIn)
  }

  // Get navigable items with backward compatibility for issueCard
  getNavigableTargets() {
    // Use navigableItem if available, otherwise fall back to issueCard
    return this.hasNavigableItemTarget ? this.navigableItemTargets : this.issueCardTargets
  }

  hasNavigableTargets() {
    return this.hasNavigableItemTarget || this.hasIssueCardTarget
  }

  handleFocusIn(event) {
    // When focus changes, clear keyboard-focused class from all cards
    // The :has() CSS selector will handle showing the green background for the focused card
    const targets = this.getNavigableTargets()
    targets.forEach(card => {
      card.classList.remove("keyboard-focused")
    })

    // Update currentFocusIndex if a navigable link is focused
    const target = event.target
    if (target && target.tagName === 'A' && target.href) {
      // Check if this link matches our configured selector
      if (target.matches(this.linkSelectorValue)) {
        // Find which navigable card contains this link
        const targetName = this.hasNavigableItemTarget ? "navigableItem" : "issueCard"
        const card = target.closest(`[data-keyboard-shortcuts-target="${targetName}"]`)
        if (card) {
          const newIndex = targets.indexOf(card)
          if (newIndex !== -1) {
            this.currentFocusIndex = newIndex
          }
        }
      }
    } else {
      // Focus moved to a non-navigable element, clear the index
      this.currentFocusIndex = -1
    }
  }

  handleKeydown(event) {
    // Don't intercept shortcuts if user is typing in an input, textarea, or contenteditable
    const target = event.target
    if (this.isTypingContext(target)) {
      // Allow Cmd/Ctrl-/ even in inputs to focus search
      if (event.key === "/" && (event.metaKey || event.ctrlKey)) {
        event.preventDefault()
        this.focusSearch()
      }
      // Allow Escape to blur the search input
      if (event.key === "Escape" && this.hasSearchInputTarget && target === this.searchInputTarget) {
        event.preventDefault()
        this.searchInputTarget.blur()
      }
      return
    }

    // Handle keyboard shortcuts
    switch (event.key) {
      case "/":
        if (!event.shiftKey) {
          event.preventDefault()
          this.focusSearch()
        } else {
          // Shift-/ shows help modal
          event.preventDefault()
          this.toggleHelp()
        }
        break
      case "?":
        // Alternative for Shift-/ (produces ? on some keyboards)
        event.preventDefault()
        this.toggleHelp()
        break
      case "j":
        event.preventDefault()
        this.focusNext()
        break
      case "k":
        event.preventDefault()
        this.focusPrevious()
        break
      case "a":
        event.preventDefault()
        this.openFilterDropdown("assignee")
        break
      case "l":
        event.preventDefault()
        this.openFilterDropdown("label")
        break
      case "u":
        event.preventDefault()
        this.openFilterDropdown("author")
        break
      case "s":
        event.preventDefault()
        this.openFilterDropdown("sort")
        break
      case "ArrowLeft":
      case "ArrowRight":
        // Handle arrow navigation between filter dropdown buttons
        if (this.isFilterDropdownButtonFocused()) {
          event.preventDefault()
          this.navigateFilterButtons(event.key === "ArrowRight")
        }
        break
      case "Escape":
        // Clear focus when Escape is pressed
        if (this.currentFocusIndex >= 0) {
          event.preventDefault()
          this.clearFocus()
        }
        break
    }
  }

  isTypingContext(element) {
    if (!element) return false

    const tagName = element.tagName.toLowerCase()
    const isContentEditable = element.isContentEditable

    return (
      tagName === "input" ||
      tagName === "textarea" ||
      tagName === "select" ||
      isContentEditable
    )
  }

  focusSearch() {
    if (this.hasSearchInputTarget) {
      this.searchInputTarget.focus()
      // Clear any issue focus when focusing search
      this.clearFocus()
    }
  }

  focusNext() {
    if (!this.hasNavigableTargets()) return

    const targets = this.getNavigableTargets()

    // Remove visual focus from previous item (but keep the index)
    targets.forEach(card => {
      card.classList.remove("keyboard-focused")
    })

    // Increment focus index
    this.currentFocusIndex++
    if (this.currentFocusIndex >= targets.length) {
      this.currentFocusIndex = targets.length - 1
    }

    this.applyFocus()
  }

  focusPrevious() {
    if (!this.hasNavigableTargets()) return

    const targets = this.getNavigableTargets()

    // Remove visual focus from previous item (but keep the index)
    targets.forEach(card => {
      card.classList.remove("keyboard-focused")
    })

    // Decrement focus index
    this.currentFocusIndex--
    if (this.currentFocusIndex < 0) {
      this.currentFocusIndex = 0
    }

    this.applyFocus()
  }

  applyFocus() {
    const targets = this.getNavigableTargets()
    if (this.currentFocusIndex >= 0 && this.currentFocusIndex < targets.length) {
      const card = targets[this.currentFocusIndex]
      card.classList.add("keyboard-focused")
      card.scrollIntoView({ behavior: "smooth", block: "nearest" })

      // Focus the link within the card
      const link = card.querySelector(this.linkSelectorValue)
      if (link) {
        link.focus()
      }
    }
  }

  clearFocus() {
    const targets = this.getNavigableTargets()
    targets.forEach(card => {
      card.classList.remove("keyboard-focused")
    })
    this.currentFocusIndex = -1
  }

  openFilterDropdown(type) {
    // Find the filter dropdown controller for the specified type
    const dropdown = document.querySelector(`[data-qualifier-type="${type}"]`)
    if (dropdown) {
      const controller = this.application.getControllerForElementAndIdentifier(
        dropdown,
        "filter-dropdown"
      )
      if (controller && !controller.isOpen()) {
        // Close other dropdowns first
        controller.closeOtherDropdowns()
        // Open this dropdown
        controller.openMenu()
      }
    }
  }

  toggleHelp() {
    if (this.hasModalTarget) {
      const isHidden = this.modalTarget.classList.contains("hidden")
      if (isHidden) {
        this.showHelp()
      } else {
        this.hideHelp()
      }
    }
  }

  showHelp() {
    if (this.hasModalTarget) {
      this.modalTarget.classList.remove("hidden")
      // Focus the modal for accessibility
      this.modalTarget.focus()
    }
  }

  hideHelp() {
    if (this.hasModalTarget) {
      this.modalTarget.classList.add("hidden")
    }
  }

  // Action for closing modal from template
  closeHelp(event) {
    event.preventDefault()
    this.hideHelp()
  }

  // Close modal when clicking outside
  closeOnOutside(event) {
    if (event.target === this.modalTarget) {
      this.hideHelp()
    }
  }

  // Check if a filter dropdown button currently has focus
  isFilterDropdownButtonFocused() {
    const activeElement = document.activeElement
    if (!activeElement) return false

    // Check if the focused element is a filter dropdown button
    return activeElement.hasAttribute('data-filter-dropdown-target') &&
          activeElement.getAttribute('data-filter-dropdown-target') === 'button'
  }

  // Navigate between filter dropdown buttons with arrow keys
  navigateFilterButtons(forward) {
    // Get all filter dropdown buttons
    const buttons = Array.from(document.querySelectorAll('[data-filter-dropdown-target="button"]'))
    if (buttons.length === 0) return

    const currentIndex = buttons.indexOf(document.activeElement)
    if (currentIndex === -1) return

    let newIndex
    if (forward) {
      // Move right (forward)
      newIndex = currentIndex + 1
      if (newIndex >= buttons.length) {
        newIndex = 0 // Wrap to first
      }
    } else {
      // Move left (backward)
      newIndex = currentIndex - 1
      if (newIndex < 0) {
        newIndex = buttons.length - 1 // Wrap to last
      }
    }

    buttons[newIndex].focus()
  }
}
