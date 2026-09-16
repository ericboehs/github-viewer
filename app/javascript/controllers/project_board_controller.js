import { Controller } from "@hotwired/stimulus"

// Assembles a project board or table out of the pages of items that arrive
// after the first.
//
// GitHub's `ProjectV2.items` takes no filter argument, so a filtered view is
// the whole project fetched and then narrowed. The server renders the first
// hundred items with the page and sends the rest through chained Turbo frames
// (see ProjectsController#items), each one delivering its items hidden and
// labelled with the column they belong in. This moves them into place.
//
// Cards carry a `data-sort-key`: a JSON array compared element by element
// against `directionsValue`. That is what lets an item fetched in the tenth
// page land above one fetched in the first, without re-sorting the board.
export default class extends Controller {
  static targets = ["board", "incoming", "columnTemplate", "status", "summary"]
  static values = { directions: Array }

  // Fired by Stimulus whenever a frame delivers another page of items.
  incomingTargetConnected(element) {
    element.querySelectorAll("[data-column-key]").forEach((group) => this.absorb(group))
    const complete = element.dataset.complete === "true"
    element.remove()

    this.refresh(complete)
  }

  // Moves one group of items into the column it belongs to.
  absorb(group) {
    const container = this.containerFor(group)
    if (!container) return

    Array.from(group.children).forEach((card) => this.insert(container, card))
  }

  // Columns of a board grouped by a field that enumerates its values are all
  // on the page already. Grouping by anything else - a repository, an assignee
  // - means a column can first appear in a later page, so one is built from
  // the template the board left behind.
  containerFor(group) {
    const key = group.dataset.columnKey
    const existing = this.boardTarget.querySelector(`[data-cards-for="${CSS.escape(key)}"]`)
    if (existing || !this.hasColumnTemplateTarget) return existing

    const column = this.columnTemplateTarget.content.firstElementChild.cloneNode(true)
    column.dataset.columnFor = key
    column.querySelector("[data-board-name]").textContent = group.dataset.columnName
    column.querySelector("[data-board-name]").className += ` ${group.dataset.columnClass || ""}`
    column.querySelector("[data-cards-for]").dataset.cardsFor = key
    this.boardTarget.appendChild(column)

    return column.querySelector("[data-cards-for]")
  }

  // Keeps each column in the view's order as cards trickle in.
  insert(container, card) {
    const key = this.sortKey(card)
    const before = Array.from(container.children).find((sibling) => this.compare(key, this.sortKey(sibling)) < 0)

    container.insertBefore(card, before || null)
  }

  sortKey(element) {
    try {
      return JSON.parse(element.dataset.sortKey || "[]")
    } catch {
      return []
    }
  }

  compare(left, right) {
    const length = Math.max(left.length, right.length)

    for (let index = 0; index < length; index++) {
      const one = String(left[index] ?? "")
      const other = String(right[index] ?? "")
      if (one === other) continue

      const order = one < other ? -1 : 1
      return this.directionsValue[index] === "desc" ? -order : order
    }

    return 0
  }

  refresh(complete) {
    let total = 0

    this.boardTarget.querySelectorAll("[data-cards-for]").forEach((container) => {
      const count = container.children.length
      total += count

      const column = container.closest("[data-column-for]")
      const badge = column && column.querySelector("[data-board-count]")
      if (badge) badge.textContent = count
    })

    if (this.hasSummaryTarget) {
      const summary = this.summaryTarget
      const template = total === 1 ? summary.dataset.one : summary.dataset.other
      summary.textContent = template.replace(/\d+/, total)
    }

    if (complete && this.hasStatusTarget) this.statusTarget.hidden = true
  }
}
