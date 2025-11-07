# frozen_string_literal: true

# Component for displaying keyboard shortcuts help modal
class KeyboardShortcutsModalComponent < ViewComponent::Base
  def initialize(shortcuts: nil)
    @shortcuts = shortcuts
  end

  def shortcuts
    @shortcuts || default_shortcuts
  end

  def default_shortcuts
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

  def call
    tag.div(
      class: "hidden fixed inset-0 bg-gray-900/80 dark:bg-black/80 z-50 flex items-center justify-center p-4",
      data: {
        keyboard_shortcuts_target: "modal",
        action: "click->keyboard-shortcuts#closeOnOutside keydown.esc->keyboard-shortcuts#closeHelp"
      },
      tabindex: "-1",
      role: "dialog",
      aria_modal: "true",
      aria_labelledby: "keyboard-shortcuts-title"
    ) do
      modal_content
    end
  end

  private

  def modal_content
    tag.div(class: "bg-white dark:bg-gray-800 rounded-lg shadow-xl max-w-2xl w-full max-h-[90vh] overflow-y-auto") do
      safe_join([
        modal_header,
        modal_body
      ])
    end
  end

  def modal_header
    tag.div(class: "px-6 py-4 border-b border-gray-200 dark:border-gray-700 flex items-center justify-between sticky top-0 bg-white dark:bg-gray-800") do
      safe_join([
        tag.h2("Keyboard shortcuts", id: "keyboard-shortcuts-title", class: "text-xl font-semibold text-gray-900 dark:text-white"),
        close_button
      ])
    end
  end

  def close_button
    tag.button(
      type: "button",
      class: "text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 transition-colors",
      data: { action: "click->keyboard-shortcuts#closeHelp" },
      aria_label: "Close"
    ) do
      tag.svg(class: "w-6 h-6", fill: "none", viewBox: "0 0 24 24", stroke: "currentColor") do
        tag.path(stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M6 18L18 6M6 6l12 12")
      end
    end
  end

  def modal_body
    tag.div(class: "px-6 py-4") do
      tag.div(class: "space-y-6") do
        shortcuts.map { |category| render_category(category) }.join.html_safe
      end
    end
  end

  def render_category(category)
    tag.div do
      safe_join([
        tag.h3(category[:category], class: "text-sm font-semibold text-gray-900 dark:text-white mb-3"),
        tag.div(class: "space-y-2") do
          category[:items].map { |item| render_shortcut(item) }.join.html_safe
        end
      ])
    end
  end

  def render_shortcut(item)
    tag.div(class: "flex items-center justify-between py-2") do
      safe_join([
        tag.div(class: "flex items-center gap-2") do
          item[:keys].map { |key| render_key(key) }.join.html_safe
        end,
        tag.div(item[:description], class: "text-sm text-gray-600 dark:text-gray-400")
      ])
    end
  end

  def render_key(key)
    tag.kbd(
      key,
      class: "px-2.5 py-1.5 text-xs font-semibold text-gray-900 dark:text-white bg-gray-100 dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded shadow-sm min-w-[2rem] text-center"
    )
  end

  def mac_platform?
    # Detect Mac platform from user agent
    user_agent = helpers.request&.user_agent.to_s
    user_agent.match?(/Mac OS X|Macintosh/i)
  rescue NoMethodError
    # Default to non-Mac if request is not available (e.g., in tests)
    false
  end
end
