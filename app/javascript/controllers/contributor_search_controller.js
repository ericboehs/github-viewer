import { Controller } from "@hotwired/stimulus"

// Stimulus controller for remote contributor search in filter dropdowns
// Debounces search input and fetches matching contributors from the API
export default class extends Controller {
  static targets = ["search", "results", "loading"]
  static values = {
    url: String,      // API endpoint URL (e.g., /repositories/1/assignable_users)
    selected: String  // Currently selected username
  }

  connect() {
    this.debounceTimer = null
    this.abortController = null

    // Load initial top contributors when controller connects
    this.loadTopContributors()
  }

  // Load top contributors (no search query)
  async loadTopContributors() {
    await this.performSearch('')
  }

  // Handle search input with debouncing
  search(event) {
    const query = event.target.value

    // Clear existing timer
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }

    // Abort any pending request
    if (this.abortController) {
      this.abortController.abort()
    }

    // Show loading state
    this.showLoading()

    // Debounce search (wait 300ms after user stops typing)
    this.debounceTimer = setTimeout(() => {
      this.performSearch(query.trim())
    }, 300)
  }

  // Perform the actual API search
  async performSearch(query) {
    // Create new abort controller for this request
    this.abortController = new AbortController()

    try {
      const url = new URL(this.urlValue, window.location.origin)
      // Only add 'q' parameter if query is not empty
      if (query) {
        url.searchParams.set('q', query)
      }
      // Pass selected value to ensure it's included in results
      if (this.selectedValue) {
        url.searchParams.set('selected', this.selectedValue)
      }

      const response = await fetch(url, {
        signal: this.abortController.signal,
        headers: {
          'Accept': 'application/json'
        }
      })

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }

      const contributors = await response.json()
      this.displayResults(contributors)
    } catch (error) {
      if (error.name !== 'AbortError') {
        console.error('Error fetching contributors:', error)
        this.showError()
      }
    } finally {
      this.hideLoading()
    }
  }

  // Display search results
  displayResults(contributors) {
    this.resultsTarget.innerHTML = ''

    if (contributors.length === 0) {
      this.showNoResults()
      return
    }

    // Sort contributors: selected first, then alphabetically
    const selected = this.selectedValue
    const sortedContributors = [...contributors].sort((a, b) => {
      if (selected) {
        if (a.login === selected) return -1
        if (b.login === selected) return 1
      }
      return a.login.localeCompare(b.login)
    })

    sortedContributors.forEach(contributor => {
      const isSelected = selected && contributor.login === selected
      const item = this.createResultItem(contributor, isSelected)
      this.resultsTarget.appendChild(item)
    })
  }

  // Create a result item element
  createResultItem(contributor, isSelected = false) {
    const button = document.createElement('button')
    button.type = 'button'
    const baseClasses = 'flex items-center gap-2 w-full px-4 py-2 text-left text-sm text-gray-700 dark:text-gray-200 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors focus:bg-gray-100 dark:focus:bg-gray-700 focus:outline-none'
    const selectedClasses = isSelected ? ' bg-gray-100 dark:bg-gray-700' : ''
    button.className = baseClasses + selectedClasses
    button.dataset.action = 'click->filter-dropdown#selectItem'
    button.dataset.value = contributor.login
    button.dataset.filterDropdownTarget = 'item'
    button.tabIndex = -1

    // Checkmark for selected item
    if (isSelected) {
      const checkmark = document.createElement('svg')
      checkmark.className = 'h-5 w-5 text-emerald-600 dark:text-emerald-400 flex-shrink-0'
      checkmark.setAttribute('viewBox', '0 0 20 20')
      checkmark.setAttribute('fill', 'currentColor')
      checkmark.innerHTML = '<path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z" clip-rule="evenodd" />'
      button.appendChild(checkmark)
    } else {
      const spacer = document.createElement('div')
      spacer.className = 'h-5 w-5 flex-shrink-0'
      button.appendChild(spacer)
    }

    // Avatar
    const avatar = document.createElement('img')
    avatar.src = contributor.avatar_url
    avatar.alt = contributor.login
    avatar.className = 'size-6 rounded-full'
    avatar.loading = 'lazy'

    // Login text
    const loginText = document.createElement('span')
    loginText.className = 'flex-1 truncate'
    loginText.textContent = contributor.login

    button.appendChild(avatar)
    button.appendChild(loginText)

    return button
  }

  // Show loading indicator
  showLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.remove('hidden')
    }
  }

  // Hide loading indicator
  hideLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.add('hidden')
    }
  }

  // Show "no results" message
  showNoResults() {
    this.resultsTarget.innerHTML = `
      <div class="px-4 py-3 text-sm text-gray-500 dark:text-gray-400 text-center">
        No contributors found
      </div>
    `
  }

  // Show error message
  showError() {
    this.resultsTarget.innerHTML = `
      <div class="px-4 py-3 text-sm text-red-600 dark:text-red-400 text-center">
        Error loading contributors
      </div>
    `
  }

  // Clear search results
  clearResults() {
    this.resultsTarget.innerHTML = ''
  }

  disconnect() {
    // Clean up timers and abort pending requests
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
    if (this.abortController) {
      this.abortController.abort()
    }
  }
}
