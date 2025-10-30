# frozen_string_literal: true

module FilterDropdown
  # Menu component for filter dropdown content
  class MenuComponent < ViewComponent::Base
    def initialize(title: nil, **options)
      @title = title
      @options = options
    end

    attr_reader :title, :options

    def menu_classes
      "absolute right-0 z-10 mt-2 w-64 origin-top-right rounded-md bg-white dark:bg-gray-800 shadow-lg ring-1 ring-black/5 dark:ring-white/10 focus:outline-hidden opacity-0 scale-95 transition ease-out duration-100 pointer-events-none"
    end
  end
end
