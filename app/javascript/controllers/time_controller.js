import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="time"
export default class extends Controller {
  connect() {
    this.updateTime()

    // Update every minute to keep relative times fresh
    this.interval = setInterval(() => {
      this.updateTime()
    }, 60000)
  }

  disconnect() {
    if (this.interval) {
      clearInterval(this.interval)
    }
  }

  updateTime() {
    const datetime = this.element.getAttribute('datetime')
    if (!datetime) return

    const date = new Date(datetime)

    // Set the text content to relative time
    this.element.textContent = this.relativeTime(date)

    // Set the title attribute to full local datetime for hover tooltip
    this.element.title = this.formatFullDate(date)
  }

  relativeTime(date) {
    const now = new Date()
    const seconds = Math.floor((now - date) / 1000)
    const minutes = Math.floor(seconds / 60)
    const hours = Math.floor(minutes / 60)
    const days = Math.floor(hours / 24)
    const months = Math.floor(days / 30)
    const years = Math.floor(days / 365)

    if (seconds < 60) {
      return 'just now'
    } else if (minutes < 60) {
      return `${minutes} ${minutes === 1 ? 'minute' : 'minutes'} ago`
    } else if (hours < 24) {
      return `${hours} ${hours === 1 ? 'hour' : 'hours'} ago`
    } else if (days < 30) {
      return `${days} ${days === 1 ? 'day' : 'days'} ago`
    } else if (months < 12) {
      return `${months} ${months === 1 ? 'month' : 'months'} ago`
    } else {
      return `${years} ${years === 1 ? 'year' : 'years'} ago`
    }
  }

  formatFullDate(date) {
    // Format: "Monday, January 1, 2025 at 3:45:30 PM EST"
    return date.toLocaleString(undefined, {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
      second: '2-digit',
      timeZoneName: 'short'
    })
  }
}
