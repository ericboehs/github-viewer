import { Controller } from "@hotwired/stimulus"

// Runs Prism over a source listing.
//
// The markdown highlighter in the layout only looks at `.markdown pre code`,
// and it rewrites the language based on the content of the block. A whole
// source file already knows its own language from its extension, so it just
// needs highlighting once, plus the line-numbers gutter.
export default class extends Controller {
  static targets = ["code"]

  connect() {
    this.highlight()
  }

  highlight() {
    // Prism comes from a CDN script tag, which may not have run yet.
    if (typeof Prism === "undefined") {
      this.retry = setTimeout(() => this.highlight(), 50)
      return
    }

    this.codeTargets.forEach((code) => {
      if (code.hasAttribute("data-prism-highlighted")) return

      Prism.highlightElement(code)
      code.setAttribute("data-prism-highlighted", "true")
    })
  }

  disconnect() {
    if (this.retry) clearTimeout(this.retry)

    // Turbo caches the DOM as-is; clearing the marker lets a restored page
    // highlight again rather than keeping stale markup.
    this.codeTargets.forEach((code) => code.removeAttribute("data-prism-highlighted"))
  }
}
