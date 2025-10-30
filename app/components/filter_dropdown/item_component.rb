# frozen_string_literal: true

module FilterDropdown
  # Item component for filter dropdown menu items
  class ItemComponent < ViewComponent::Base
    def initialize(text:, value: nil, avatar_url: nil, selected: false, icon: nil, **options)
      @text = text
      @value = value || text
      @avatar_url = avatar_url
      @selected = selected
      @icon = icon
      @options = options
    end

    def call
      tag.button(
        type: "button",
        class: item_classes,
        role: "menuitem",
        tabindex: "0",
        data: {
          filter_dropdown_target: "item",
          action: "click->filter-dropdown#selectItem",
          value: @value
        }
      ) do
        safe_join([
          render_avatar_or_icon,
          render_text,
          render_checkmark
        ].compact)
      end
    end

    private

    attr_reader :text, :value, :avatar_url, :selected, :icon, :options

    def item_classes
      base = "group flex w-full items-center gap-2 px-4 py-2 text-left text-sm text-gray-700 dark:text-gray-200 hover:bg-gray-100 dark:hover:bg-gray-700 focus:bg-gray-100 dark:focus:bg-gray-700 focus:outline-none"
      selected ? "#{base} bg-gray-50 dark:bg-gray-750" : base
    end

    def render_avatar_or_icon
      if avatar_url
        tag.img(
          src: avatar_url,
          alt: text,
          class: "h-5 w-5 rounded-full flex-shrink-0"
        )
      elsif icon == :user
        tag.svg(class: "h-5 w-5 text-gray-400 flex-shrink-0", fill: "currentColor", viewBox: "0 0 16 16") do
          tag.path(d: "M8 8a3 3 0 1 0 0-6 3 3 0 0 0 0 6ZM12.5 14c0-1.381-1.119-2.5-2.5-2.5H6c-1.381 0-2.5 1.119-2.5 2.5v.5h9v-.5Z")
        end
      end
    end

    def render_text
      tag.span(text, class: "flex-1 truncate")
    end

    def render_checkmark
      return unless selected

      tag.svg(class: "h-4 w-4 text-blue-600", fill: "currentColor", viewBox: "0 0 16 16") do
        tag.path(d: "M13.78 4.22a.75.75 0 0 1 0 1.06l-7.25 7.25a.75.75 0 0 1-1.06 0L2.22 9.28a.75.75 0 0 1 1.06-1.06L6 10.94l6.72-6.72a.75.75 0 0 1 1.06 0Z")
      end
    end
  end
end
