# frozen_string_literal: true

# Component for displaying GitHub issue state (open/closed)
class IssueStateComponent < ViewComponent::Base
  def initialize(state:)
    @state = state
  end

  def call
    tag.span(class: state_classes) do
      safe_join([ state_icon, state_text ], " ")
    end
  end

  private

  def state_classes
    base_classes = "inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium"

    if @state == "open"
      "#{base_classes} bg-green-100 text-green-800 dark:bg-green-900/20 dark:text-green-400"
    else
      "#{base_classes} bg-purple-100 text-purple-800 dark:bg-purple-900/20 dark:text-purple-400"
    end
  end

  def state_icon
    if @state == "open"
      # Open circle icon
      svg_icon do
        tag.path(d: "M8 1.5a6.5 6.5 0 100 13 6.5 6.5 0 000-13zM0 8a8 8 0 1116 0A8 8 0 010 8z")
      end
    else
      # Check circle icon
      svg_icon do
        tag.path(d: "M8 16A8 8 0 1 0 8 0a8 8 0 0 0 0 16zm3.78-9.72a.751.751 0 0 0-.018-1.042.751.751 0 0 0-1.042-.018L6.75 9.19 5.28 7.72a.751.751 0 0 0-1.042.018.751.751 0 0 0-.018 1.042l2 2a.75.75 0 0 0 1.06 0z")
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
