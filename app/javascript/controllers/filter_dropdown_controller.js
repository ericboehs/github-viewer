import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "menu", "search", "item"]

  connect() {
    this.close = this.close.bind(this)
    this.handleKeydown = this.handleKeydown.bind(this)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    if (this.isOpen()) {
      this.closeMenu()
    } else {
      // Close all other open dropdowns before opening this one
      this.closeOtherDropdowns()
      this.openMenu()
    }
  }

  openMenu() {
    this.menuTarget.classList.remove("opacity-0", "scale-95", "pointer-events-none")
    this.menuTarget.classList.add("opacity-100", "scale-100")
    this.menuTarget.removeAttribute("inert")
    this.buttonTarget.setAttribute("aria-expanded", "true")

    // Adjust positioning based on available space
    this.adjustPosition()

    // Focus search input if it exists
    if (this.hasSearchTarget) {
      setTimeout(() => this.searchTarget.focus(), 100)
    }

    // Add event listeners
    document.addEventListener("click", this.close)
    document.addEventListener("keydown", this.handleKeydown)
  }

  adjustPosition() {
    // Get the button and menu positions
    const buttonRect = this.buttonTarget.getBoundingClientRect()
    const viewportWidth = window.innerWidth

    // Calculate space on right and left (from button edges to viewport edges)
    const spaceOnRight = viewportWidth - buttonRect.right
    const spaceOnLeft = buttonRect.left

    // Menu width is typically 224px (w-56), add 16px buffer for padding
    const menuWidth = 224
    const buffer = 16

    // Decision logic:
    // - If there's enough space on the right, anchor to the LEFT edge (left-0) - menu extends right
    // - If there's not enough space on the right but enough on the left, anchor to the RIGHT edge (right-0) - menu extends left
    // - Prefer left-anchored (extending right) when there's enough space
    if (spaceOnRight >= menuWidth + buffer) {
      // Enough space on right, anchor left (menu extends right)
      this.menuTarget.classList.remove("right-0", "origin-top-right")
      this.menuTarget.classList.add("left-0", "origin-top-left")
    } else if (spaceOnLeft >= menuWidth + buffer) {
      // Not enough space on right but enough on left, anchor right (menu extends left)
      this.menuTarget.classList.remove("left-0", "origin-top-left")
      this.menuTarget.classList.add("right-0", "origin-top-right")
    } else {
      // Not enough space on either side, default to right anchor
      this.menuTarget.classList.remove("left-0", "origin-top-left")
      this.menuTarget.classList.add("right-0", "origin-top-right")
    }
  }

  closeMenu() {
    this.menuTarget.classList.remove("opacity-100", "scale-100")
    this.menuTarget.classList.add("opacity-0", "scale-95", "pointer-events-none")
    this.menuTarget.setAttribute("inert", "")
    this.buttonTarget.setAttribute("aria-expanded", "false")

    // Restore focus to button
    this.buttonTarget.focus()

    // Remove event listeners
    document.removeEventListener("click", this.close)
    document.removeEventListener("keydown", this.handleKeydown)
  }

  close(event) {
    if (!this.element.contains(event.target)) {
      this.closeMenu()
    }
  }

  closeOtherDropdowns() {
    // Find all other filter dropdown controllers and close them
    document.querySelectorAll('[data-controller="filter-dropdown"]').forEach(element => {
      if (element !== this.element) {
        const controller = this.application.getControllerForElementAndIdentifier(element, "filter-dropdown")
        if (controller && controller.isOpen()) {
          controller.closeMenu()
        }
      }
    })
  }

  isOpen() {
    return this.menuTarget.classList.contains("opacity-100")
  }

  search(event) {
    const query = event.target.value.toLowerCase()

    this.itemTargets.forEach(item => {
      const text = item.textContent.toLowerCase()
      if (text.includes(query)) {
        item.classList.remove("hidden")
      } else {
        item.classList.add("hidden")
      }
    })
  }

  selectItem(event) {
    const button = event.currentTarget
    const value = button.dataset.value
    const qualifierType = this.element.dataset.qualifierType

    // Get the search field
    const form = this.element.closest("form")
    const searchField = form ? form.querySelector('input[name="q"]') : null

    if (searchField && qualifierType) {
      let query = searchField.value || ''

      // Create regex to match the qualifier type (e.g., assignee:, label:)
      const qualifierRegex = new RegExp(`\\b${qualifierType}:("[^"]*"|\\S+)`, 'gi')

      // Remove existing qualifier of this type
      query = query.replace(qualifierRegex, '').trim()

      // Add new qualifier if value is not empty
      if (value) {
        // Quote the value if it contains spaces
        const quotedValue = value.includes(' ') ? `"${value}"` : value
        // Add qualifier at the end of the query
        query = query ? `${query} ${qualifierType}:${quotedValue}` : `${qualifierType}:${quotedValue}`
      }

      // Normalize whitespace
      searchField.value = query.replace(/\s+/g, ' ').trim()
    }

    // Automatically close and submit the form
    this.closeMenu()
    if (form) {
      // Use Turbo to submit the form
      form.requestSubmit()
    }
  }

  handleKeydown(event) {
    if (!this.isOpen()) return

    switch (event.key) {
      case "Escape":
        event.preventDefault()
        this.closeMenu()
        break
      case "Enter":
        // If search input is focused, select the first visible item
        if (document.activeElement === this.searchTarget) {
          event.preventDefault()
          const menuItems = this.getVisibleMenuItems()
          if (menuItems.length > 0) {
            menuItems[0].click()
          }
        }
        break
      case "ArrowDown":
        event.preventDefault()
        this.focusNextMenuItem()
        break
      case "ArrowUp":
        event.preventDefault()
        this.focusPreviousMenuItem()
        break
      case "Home":
        event.preventDefault()
        this.focusFirstMenuItem()
        break
      case "End":
        event.preventDefault()
        this.focusLastMenuItem()
        break
    }
  }

  focusFirstMenuItem() {
    const menuItems = this.getVisibleMenuItems()
    if (menuItems.length > 0) {
      menuItems[0].focus()
    }
  }

  focusLastMenuItem() {
    const menuItems = this.getVisibleMenuItems()
    if (menuItems.length > 0) {
      menuItems[menuItems.length - 1].focus()
    }
  }

  focusNextMenuItem() {
    const menuItems = this.getVisibleMenuItems()
    const currentIndex = this.getCurrentMenuItemIndex(menuItems)

    if (currentIndex === -1 || document.activeElement === this.searchTarget) {
      // No item focused or search focused, focus first item
      if (menuItems.length > 0) {
        menuItems[0].focus()
      }
    } else if (currentIndex < menuItems.length - 1) {
      // Focus next item
      menuItems[currentIndex + 1].focus()
    }
  }

  focusPreviousMenuItem() {
    const menuItems = this.getVisibleMenuItems()
    const currentIndex = this.getCurrentMenuItemIndex(menuItems)

    if (currentIndex === -1) {
      // No item focused, focus last item
      if (menuItems.length > 0) {
        menuItems[menuItems.length - 1].focus()
      }
    } else if (currentIndex === 0) {
      // First item focused, focus search input
      if (this.hasSearchTarget) {
        this.searchTarget.focus()
      }
    } else if (currentIndex > 0) {
      // Focus previous item
      menuItems[currentIndex - 1].focus()
    }
  }

  getVisibleMenuItems() {
    // Get all visible, focusable menu items
    return this.itemTargets.filter(item =>
      !item.classList.contains("hidden") &&
      !item.hasAttribute("disabled")
    )
  }

  getCurrentMenuItemIndex(menuItems) {
    return menuItems.findIndex(item => item === document.activeElement)
  }

  disconnect() {
    document.removeEventListener("click", this.close)
    document.removeEventListener("keydown", this.handleKeydown)
  }
}
