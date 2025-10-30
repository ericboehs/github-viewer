# frozen_string_literal: true

# Component for displaying GitHub issue state (open/closed)
class IssueStateComponent < ViewComponent::Base
  def initialize(state:, show_text: false)
    @state = state
    @show_text = show_text
  end

  def call
    tag.span(class: state_classes) do
      if @show_text
        safe_join([ state_icon, state_text ], " ")
      else
        state_icon
      end
    end
  end

  private

  def state_classes
    base_classes = "inline-flex items-center gap-1"

    if @show_text
      # With text, show background
      text_classes = "px-2 py-1 rounded-full text-xs font-medium"
      if @state == "open"
        "#{base_classes} #{text_classes} bg-green-100 text-green-800 dark:bg-green-900/20 dark:text-green-400"
      else
        "#{base_classes} #{text_classes} bg-purple-100 text-purple-800 dark:bg-purple-900/20 dark:text-purple-400"
      end
    else
      # Icon only, just color
      if @state == "open"
        "#{base_classes} text-green-600 dark:text-green-500"
      else
        "#{base_classes} text-purple-600 dark:text-purple-500"
      end
    end
  end

  def state_icon
    if @state == "open"
      # Open circle icon (GitHub octicon)
      svg_icon do
        safe_join([
          tag.path(d: "M8 9.5a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3Z"),
          tag.path(d: "M8 0a8 8 0 1 1 0 16A8 8 0 0 1 8 0ZM1.5 8a6.5 6.5 0 1 0 13 0 6.5 6.5 0 0 0-13 0Z")
        ])
      end
    else
      # Closed circle icon (GitHub octicon)
      svg_icon do
        safe_join([
          tag.path(d: "M11.28 6.78a.75.75 0 0 0-1.06-1.06L7.25 8.69 5.78 7.22a.75.75 0 0 0-1.06 1.06l2 2a.75.75 0 0 0 1.06 0l3.5-3.5Z"),
          tag.path(d: "M16 8A8 8 0 1 1 0 8a8 8 0 0 1 16 0Zm-1.5 0a6.5 6.5 0 1 0-13 0 6.5 6.5 0 0 0 13 0Z")
        ])
      end
    end
  end

  def svg_icon(&block)
    tag.svg(class: "w-4 h-4", fill: "currentColor", viewBox: "0 0 16 16", xmlns: "http://www.w3.org/2000/svg", &block)
  end

  def state_text
    @state.capitalize
  end
end
