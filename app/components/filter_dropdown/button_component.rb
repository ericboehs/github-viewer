# frozen_string_literal: true

module FilterDropdown
  # Button component for opening filter dropdown
  class ButtonComponent < ViewComponent::Base
    def initialize(text:, **options)
      @text = text
      @options = options
    end

    private

    attr_reader :text, :options

    def button_classes
      "inline-flex w-full justify-center gap-x-1.5 rounded-md px-3 py-2 text-sm font-medium shadow-sm ring-1 ring-inset bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 ring-gray-300 dark:ring-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700"
    end

    def chevron_classes
      "-mr-1 size-5 text-gray-400"
    end
  end
end
