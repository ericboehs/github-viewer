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

  def field_display_value(value)
    # Handle different value types
    case value
    when Numeric
      # Show numbers as integers if they have no decimal component
      value % 1 == 0 ? value.to_i.to_s : value.to_s
    when String
      value.present? ? value : "None"
    else
      value.to_s
    end
  end
end
