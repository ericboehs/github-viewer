import { Controller } from "@hotwired/stimulus"

// Stimulus controller for contributor search in filter dropdowns
// Fetches repository assignees from GitHub REST API once and caches client-side
export default class extends Controller {
  static targets = ["search", "results", "loading"]
  static values = {
    url: String,      // API endpoint URL (e.g., /repositories/1/assignable_users)
    selected: String  // Currently selected username
  }

  connect() {
    this.debounceTimer = null
    this.abortController = null
    this.searchAbortController = null  // Separate abort controller for search requests
    this.cachedContributors = null  // Cache full list client-side

    // Fetch and cache contributors on page load
    this.loadContributors()
  }

  // Fetch contributors from API once and cache
  async loadContributors() {
    // Show loading state
    this.showLoading()

    // Create abort controller for this request
    this.abortController = new AbortController()

    try {
      const url = new URL(this.urlValue, window.location.origin)
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

      // Cache the full list for client-side filtering
      this.cachedContributors = contributors

      // Display initial list
      this.displayResults(this.cachedContributors)
    } catch (error) {
      if (error.name !== 'AbortError') {
        console.error('Error fetching contributors:', error)
        this.showError()
      }
    } finally {
      this.hideLoading()
    }
  }

  // Handle search input with debouncing
  search(event) {
    const query = event.target.value

    // Clear existing timer
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }

    // Debounce search (wait 300ms after user stops typing)
    this.debounceTimer = setTimeout(() => {
      this.performSearch(query.trim())
    }, 300)
  }

  // Perform search - use API for queries, cached data when empty
  async performSearch(query) {
    // If no query, restore cached initial list
    if (!query) {
      if (this.cachedContributors) {
        this.displayResults(this.cachedContributors)
      }
      return
    }

    // Make API call with search query
    this.showLoading()

    // Abort any pending request
    if (this.searchAbortController) {
      this.searchAbortController.abort()
    }
    this.searchAbortController = new AbortController()

    try {
      const url = new URL(this.urlValue, window.location.origin)
      url.searchParams.set('q', query)

      // Pass selected value to ensure it's included in results
      if (this.selectedValue) {
        url.searchParams.set('selected', this.selectedValue)
      }

      const response = await fetch(url, {
        signal: this.searchAbortController.signal,
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
        console.error('Error searching contributors:', error)
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

    // Trust server-side ordering (selected first, then current user, then everyone else)
    // Don't re-sort client-side
    const selected = this.selectedValue

    contributors.forEach(contributor => {
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
    button.className = baseClasses
    button.dataset.action = 'click->filter-dropdown#selectItem'
    button.dataset.value = contributor.login
    button.dataset.filterDropdownTarget = 'item'
    button.tabIndex = -1

    // Checkmark for selected item (no background highlight, just checkmark)
    if (isSelected) {
      const checkmark = document.createElementNS('http://www.w3.org/2000/svg', 'svg')
      checkmark.setAttribute('class', 'h-5 w-5 text-emerald-600 dark:text-emerald-400 flex-shrink-0')
      checkmark.setAttribute('viewBox', '0 0 20 20')
      checkmark.setAttribute('fill', 'currentColor')

      const path = document.createElementNS('http://www.w3.org/2000/svg', 'path')
      path.setAttribute('fill-rule', 'evenodd')
      path.setAttribute('d', 'M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z')
      path.setAttribute('clip-rule', 'evenodd')

      checkmark.appendChild(path)
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
    if (this.searchAbortController) {
      this.searchAbortController.abort()
    }
    // Clear cache
    this.cachedContributors = null
  }
}
