# frozen_string_literal: true

# Component for displaying GitHub issue state (open/closed)
# :reek:BooleanParameter - show_text is an optional display flag
class IssueStateComponent < ViewComponent::Base
  STATE_CONFIG = {
    "open" => {
      badge_classes: "bg-green-200 text-green-900 dark:bg-green-900/30 dark:text-green-300",
      icon_classes: "text-green-600 dark:text-green-500",
      icon_paths: [
        "M8 9.5a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3Z",
        "M8 0a8 8 0 1 1 0 16A8 8 0 0 1 8 0ZM1.5 8a6.5 6.5 0 1 0 13 0 6.5 6.5 0 0 0-13 0Z"
      ]
    },
    "closed" => {
      badge_classes: "bg-purple-200 text-purple-900 dark:bg-purple-900/30 dark:text-purple-300",
      icon_classes: "text-purple-600 dark:text-purple-500",
      icon_paths: [
        "M11.28 6.78a.75.75 0 0 0-1.06-1.06L7.25 8.69 5.78 7.22a.75.75 0 0 0-1.06 1.06l2 2a.75.75 0 0 0 1.06 0l3.5-3.5Z",
        "M16 8A8 8 0 1 1 0 8a8 8 0 0 1 16 0Zm-1.5 0a6.5 6.5 0 1 0-13 0 6.5 6.5 0 0 0 13 0Z"
      ]
    }
  }.freeze

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
    base = "inline-flex items-center"
    config = STATE_CONFIG[@state]

    if @show_text
      "#{base} gap-x-1.5 rounded-full px-2.5 py-1.5 text-sm font-medium #{config[:badge_classes]}"
    else
      "#{base} gap-1 #{config[:icon_classes]}"
    end
  end

  def state_icon
    config = STATE_CONFIG[@state]
    svg_icon do
      safe_join(config[:icon_paths].map { |path_data| tag.path(d: path_data) })
    end
  end

  def svg_icon(&block)
    tag.svg(class: "w-5 h-5", fill: "currentColor", viewBox: "0 0 16 16", xmlns: "http://www.w3.org/2000/svg", &block)
  end

  def state_text
    @state.capitalize
  end
end
