# frozen_string_literal: true

# Component for displaying GitHub Projects V2 fields in sidebar
# Shows project memberships and field values (Status, Sprint, Priority, Estimate, etc.)
class ProjectFieldsComponent < ViewComponent::Base
  def initialize(project_items:)
    @project_items = project_items
  end

  def render?
    @project_items.present?
  end

  private

  # :reek:UtilityFunction - Pure helper for formatting field values, appropriate as private method
  # :reek:TooManyStatements - Simple case statement for different value types
  # :reek:DuplicateMethodCall - value.to_s called in different case branches for type handling
  def field_display_value(value)
    # Handle different value types
    case value
    when Numeric
      # Show numbers as integers if they have no decimal component
      string_value = value.to_s
      value % 1 == 0 ? value.to_i.to_s : string_value
    when String
      value.present? ? value : "None"
    else
      value.to_s
    end
  end
end
