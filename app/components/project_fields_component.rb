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

  # This application serves project pages at GitHub's own paths, so a project
  # an issue belongs to is a link into it rather than out to github.com. A URL
  # the router does not recognise - a classic project, say - stays external.
  #
  # :reek:UtilityFunction - Link helper, at home beside the rest of the display logic
  def local_path(url)
    GithubLink.path_for(url) if url.present?
  end

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
