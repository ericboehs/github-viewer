import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["mobileMenu", "mobileOpenIcon", "mobileCloseIcon", "dropdown", "button"]

  toggleMobileMenu() {
    this.mobileMenuTarget.classList.toggle("hidden")
    this.mobileOpenIconTarget.classList.toggle("hidden")
    this.mobileOpenIconTarget.classList.toggle("block")
    this.mobileCloseIconTarget.classList.toggle("hidden")
    this.mobileCloseIconTarget.classList.toggle("block")

    // Update aria-expanded
    const button = this.element.querySelector('[aria-controls="mobile-menu"]')
    const expanded = button.getAttribute("aria-expanded") === "true"
    button.setAttribute("aria-expanded", !expanded)

    // Add/remove keydown listener for mobile menu
    if (!expanded) {
      document.addEventListener("keydown", this.handleMobileMenuKeydown.bind(this))
    } else {
      document.removeEventListener("keydown", this.handleMobileMenuKeydown.bind(this))
    }
  }

  handleMobileButtonKeydown(event) {
    // Open mobile menu when pressing down arrow or enter on button
    if ((event.key === "ArrowDown" || event.key === "Enter") && this.isMobileMenuClosed()) {
      event.preventDefault()
      event.stopPropagation()
      this.toggleMobileMenu()

      // Focus first menu item
      setTimeout(() => {
        const menuItems = this.getMobileMenuItems()
        if (menuItems.length > 0) {
          menuItems[0].focus()
        }
      }, 100)
    }
  }

  isMobileMenuClosed() {
    return this.mobileMenuTarget.classList.contains("hidden")
  }

  handleMobileMenuKeydown(event) {
    if (this.isMobileMenuClosed()) return

    switch (event.key) {
      case "Escape":
        event.preventDefault()
        this.closeMobileMenu()
        break
      case "Tab":
        this.closeMobileMenu()
        break
      case "ArrowDown":
        event.preventDefault()
        this.focusNextMobileMenuItem()
        break
      case "ArrowUp":
        event.preventDefault()
        const menuItems = this.getMobileMenuItems()
        const currentIndex = this.getCurrentMobileMenuItemIndex(menuItems)
        if (currentIndex === 0) {
          this.closeMobileMenu()
        } else {
          this.focusPreviousMobileMenuItem()
        }
        break
    }
  }

  closeMobileMenu() {
    if (!this.isMobileMenuClosed()) {
      this.mobileMenuTarget.classList.add("hidden")
      this.mobileOpenIconTarget.classList.remove("hidden")
      this.mobileOpenIconTarget.classList.add("block")
      this.mobileCloseIconTarget.classList.add("hidden")
      this.mobileCloseIconTarget.classList.remove("block")

      const button = this.element.querySelector('[aria-controls="mobile-menu"]')
      button.setAttribute("aria-expanded", "false")
      button.focus()

      document.removeEventListener("keydown", this.handleMobileMenuKeydown.bind(this))
    }
  }

  getMobileMenuItems() {
    return Array.from(this.mobileMenuTarget.querySelectorAll('a'))
  }

  getCurrentMobileMenuItemIndex(menuItems) {
    return menuItems.findIndex(item => item === document.activeElement)
  }

  focusNextMobileMenuItem() {
    const menuItems = this.getMobileMenuItems()
    const currentIndex = this.getCurrentMobileMenuItemIndex(menuItems)

    if (currentIndex === -1) {
      if (menuItems.length > 0) {
        menuItems[0].focus()
      }
    } else if (currentIndex < menuItems.length - 1) {
      menuItems[currentIndex + 1].focus()
    }
  }

  focusPreviousMobileMenuItem() {
    const menuItems = this.getMobileMenuItems()
    const currentIndex = this.getCurrentMobileMenuItemIndex(menuItems)

    if (currentIndex > 0) {
      menuItems[currentIndex - 1].focus()
    }
  }

  toggleDropdown() {
    this.dropdownTarget.classList.toggle("hidden")

    // Update aria-expanded
    const button = this.element.querySelector('[aria-haspopup="true"]')
    const expanded = button.getAttribute("aria-expanded") === "true"
    button.setAttribute("aria-expanded", !expanded)
  }

  handleButtonKeydown(event) {
    // Open dropdown when pressing down arrow or enter on button
    if ((event.key === "ArrowDown" || event.key === "Enter") && this.isDropdownClosed()) {
      event.preventDefault()
      event.stopPropagation()
      this.openDropdown()

      // Focus first menu item
      setTimeout(() => {
        const menuItems = this.getMenuItems()
        if (menuItems.length > 0) {
          menuItems[0].focus()
        }
      }, 100)
    }
  }

  openDropdown() {
    this.dropdownTarget.classList.remove("hidden")
    const button = this.element.querySelector('[aria-haspopup="true"]')
    button.setAttribute("aria-expanded", "true")

    // Add keydown listener for menu navigation
    document.addEventListener("keydown", this.handleMenuKeydown.bind(this))
  }

  closeDropdown() {
    this.dropdownTarget.classList.add("hidden")
    const button = this.element.querySelector('[aria-haspopup="true"]')
    button.setAttribute("aria-expanded", "false")

    // Return focus to button
    button.focus()

    // Remove keydown listener
    document.removeEventListener("keydown", this.handleMenuKeydown.bind(this))
  }

  isDropdownClosed() {
    return this.dropdownTarget.classList.contains("hidden")
  }

  handleMenuKeydown(event) {
    if (this.isDropdownClosed()) return

    switch (event.key) {
      case "Escape":
        event.preventDefault()
        this.closeDropdown()
        break
      case "Tab":
        this.closeDropdown()
        break
      case "ArrowDown":
        event.preventDefault()
        this.focusNextMenuItem()
        break
      case "ArrowUp":
        event.preventDefault()
        const menuItems = this.getMenuItems()
        const currentIndex = this.getCurrentMenuItemIndex(menuItems)
        if (currentIndex === 0) {
          this.closeDropdown()
        } else {
          this.focusPreviousMenuItem()
        }
        break
    }
  }

  getMenuItems() {
    return Array.from(this.dropdownTarget.querySelectorAll('a[role="menuitem"]'))
  }

  getCurrentMenuItemIndex(menuItems) {
    return menuItems.findIndex(item => item === document.activeElement)
  }

  focusNextMenuItem() {
    const menuItems = this.getMenuItems()
    const currentIndex = this.getCurrentMenuItemIndex(menuItems)

    if (currentIndex === -1) {
      if (menuItems.length > 0) {
        menuItems[0].focus()
      }
    } else if (currentIndex < menuItems.length - 1) {
      menuItems[currentIndex + 1].focus()
    }
  }

  focusPreviousMenuItem() {
    const menuItems = this.getMenuItems()
    const currentIndex = this.getCurrentMenuItemIndex(menuItems)

    if (currentIndex > 0) {
      menuItems[currentIndex - 1].focus()
    }
  }

  hideDropdown(event) {
    if (!this.element.contains(event.target)) {
      this.dropdownTarget.classList.add("hidden")
      const button = this.element.querySelector('[aria-haspopup="true"]')
      button.setAttribute("aria-expanded", "false")
    }
  }

  connect() {
    // Close dropdown when clicking outside
    document.addEventListener("click", this.hideDropdown.bind(this))
  }

  disconnect() {
    document.removeEventListener("click", this.hideDropdown.bind(this))
    document.removeEventListener("keydown", this.handleMenuKeydown.bind(this))
  }
}
