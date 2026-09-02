import { Controller } from "@hotwired/stimulus"

// Runs Prism over a source listing or a diff.
//
// The markdown highlighter in the layout only looks at `.markdown pre code`,
// and it rewrites the language based on the content of the block. A source
// file already knows its language from its path, so it just needs
// highlighting once.
//
// Two shapes are supported:
//
//   code targets — a whole file in one <pre><code>, highlighted as a unit so
//   that strings and comments spanning lines come out right.
//
//   line targets — one span per diff row. A diff cannot be highlighted as a
//   unit because its lines are interleaved with markers, numbers and row
//   backgrounds, so each line is lexed on its own. A construct spanning
//   several lines will not be recognised; that is inherent to highlighting a
//   diff, and GitHub has the same limitation.
export default class extends Controller {
  static targets = ["code", "line"]
  static values = { language: String }

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

    this.highlightLines()
  }

  highlightLines() {
    if (!this.hasLineTarget) return

    const language = this.languageValue
    const grammar = language && Prism.languages[language]
    if (!grammar) return

    this.lineTargets.forEach((line) => {
      if (line.hasAttribute("data-prism-highlighted")) return

      // textContent, so a re-highlight after a Turbo restore starts from the
      // plain source rather than from the previous run's markup.
      line.innerHTML = Prism.highlight(line.textContent, grammar, language)
      line.setAttribute("data-prism-highlighted", "true")
    })
  }

  disconnect() {
    if (this.retry) clearTimeout(this.retry)

    // Turbo caches the DOM as-is; clearing the marker lets a restored page
    // highlight again rather than keeping stale markup.
    const targets = [...this.codeTargets, ...this.lineTargets]
    targets.forEach((element) => element.removeAttribute("data-prism-highlighted"))
  }
}
