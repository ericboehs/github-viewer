# frozen_string_literal: true

module FilterDropdown
  # Base component for filter dropdowns with search and keyboard navigation
  class BaseComponent < ViewComponent::Base
    def initialize(qualifier_type:, **options)
      @qualifier_type = qualifier_type
      @options = options
    end

    attr_reader :qualifier_type, :options

    def dropdown_data
      {
        controller: "filter-dropdown",
        qualifier_type: qualifier_type,
        **options.fetch(:data, {})
      }
    end

    def dropdown_classes
      "relative inline-block text-left"
    end
  end
end
