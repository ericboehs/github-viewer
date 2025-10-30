# frozen_string_literal: true

module FilterDropdown
  # Search input component for filtering dropdown items
  class SearchComponent < ViewComponent::Base
    def initialize(placeholder: "Filter...", **options)
      @placeholder = placeholder
      @options = options
    end

    private

    attr_reader :placeholder, :options

    def input_classes
      "block w-full rounded-md border-0 bg-white dark:bg-gray-900 px-3 py-2 text-sm text-gray-900 dark:text-white placeholder:text-gray-400 dark:placeholder:text-gray-500 focus:outline-none focus:ring-2 focus:ring-blue-600 dark:focus:ring-blue-500"
    end
  end
end
