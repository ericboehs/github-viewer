# frozen_string_literal: true

# Helper module for keyboard shortcuts configurations
module KeyboardShortcutsHelper
  # Keyboard shortcuts for issues index page
  def issue_shortcuts
    [
      { category: "Navigation", items: [
        { keys: [ "j", "k" ], description: "Next/previous issue" },
        { keys: [ "Esc" ], description: "Clear focus" }
      ] },
      { category: "Search & Filters", items: [
        { keys: [ mac_platform? ? "Cmd-/" : "Ctrl-/" ], description: "Focus search bar" },
        { keys: [ "a" ], description: "Open assignees filter" },
        { keys: [ "l" ], description: "Open labels filter" },
        { keys: [ "u" ], description: "Open authors filter" },
        { keys: [ "s" ], description: "Open sort filter" }
      ] },
      { category: "Help", items: [
        { keys: [ "Shift-/" ], description: "Show/hide keyboard shortcuts" }
      ] }
    ]
  end

  # Keyboard shortcuts for repositories index page
  def repository_shortcuts
    [
      { category: "Navigation", items: [
        { keys: [ "j", "k" ], description: "Next/previous repository" },
        { keys: [ "Esc" ], description: "Clear focus" }
      ] },
      { category: "Search", items: [
        { keys: [ mac_platform? ? "Cmd-/" : "Ctrl-/" ], description: "Focus search bar" }
      ] },
      { category: "Help", items: [
        { keys: [ "Shift-/" ], description: "Show/hide keyboard shortcuts" }
      ] }
    ]
  end

  # Base shortcuts common to all pages
  def base_shortcuts
    [
      { category: "Navigation", items: [
        { keys: [ "j", "k" ], description: "Next/previous item" },
        { keys: [ "Esc" ], description: "Clear focus" }
      ] },
      { category: "Search", items: [
        { keys: [ mac_platform? ? "Cmd-/" : "Ctrl-/" ], description: "Focus search bar" }
      ] },
      { category: "Help", items: [
        { keys: [ "Shift-/" ], description: "Show/hide keyboard shortcuts" }
      ] }
    ]
  end

  private

  def mac_platform?
    # Detect Mac platform from user agent
    user_agent = request&.user_agent.to_s
    user_agent.match?(/Mac OS X|Macintosh/i)
  rescue NoMethodError
    # Default to non-Mac if request is not available (e.g., in tests)
    false
  end
end
