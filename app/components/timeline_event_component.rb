# frozen_string_literal: true

# Component for displaying timeline events (labels, milestones, projects, comments)
# :reek:TooManyInstanceVariables - Extracts data from item hash for view access
class TimelineEventComponent < ViewComponent::Base
  def initialize(item:, repository: nil)
    @item = item
    @type = item[:type]
    @repository = repository
  end

  def render?
    @item.present?
  end

  private

  def is_comment?
    @type == "comment"
  end

  def event_icon_svg
    case @type
    when "labeled", "unlabeled"
      tag_icon
    when "milestoned", "demilestoned"
      milestone_icon
    when "added_to_project", "removed_from_project"
      project_icon
    when "status_changed"
      arrow_icon
    else
      ""
    end
  end

  # :reek:TooManyStatements - Simple case statement mapping event types to text
  def event_text
    case @type
    when "labeled"
      "added"
    when "unlabeled"
      "removed"
    when "milestoned"
      "added this to the"
    when "demilestoned"
      "removed this from the"
    when "added_to_project"
      "added this to"
    when "removed_from_project"
      "removed this from"
    when "status_changed"
      "changed status in"
    else
      ""
    end
  end

  # SVG icon definitions
  # :reek:UtilityFunction - Static SVG helper, appropriate as private method
  def tag_icon
    <<~SVG.html_safe
      <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M17.707 9.293a1 1 0 010 1.414l-7 7a1 1 0 01-1.414 0l-7-7A.997.997 0 012 10V5a3 3 0 013-3h5c.256 0 .512.098.707.293l7 7zM5 6a1 1 0 100-2 1 1 0 000 2z" clip-rule="evenodd" />
      </svg>
    SVG
  end

  # :reek:UtilityFunction - Static SVG helper, appropriate as private method
  def milestone_icon
    <<~SVG.html_safe
      <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
        <path d="M2 6a2 2 0 012-2h12a2 2 0 012 2v2a2 2 0 01-2 2H4a2 2 0 01-2-2V6zM14.553 7.106A1 1 0 0014 8a1 1 0 00-.553.894l2 7A1 1 0 0017 16h-2.586l-1.707-1.707a1 1 0 00-1.414 0l-1.707 1.707H7a1 1 0 001.553-.894l2-7A1 1 0 0010 8a1 1 0 00-.553-.894l-2-7A1 1 0 007 0h6a1 1 0 00.553.894l2 7z" />
      </svg>
    SVG
  end

  # :reek:UtilityFunction - Static SVG helper, appropriate as private method
  def project_icon
    <<~SVG.html_safe
      <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
        <path d="M3 4a1 1 0 011-1h12a1 1 0 011 1v2a1 1 0 01-1 1H4a1 1 0 01-1-1V4zM3 10a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H4a1 1 0 01-1-1v-6zM14 9a1 1 0 00-1 1v6a1 1 0 001 1h2a1 1 0 001-1v-6a1 1 0 00-1-1h-2z" />
      </svg>
    SVG
  end

  # :reek:UtilityFunction - Static SVG helper, appropriate as private method
  def arrow_icon
    <<~SVG.html_safe
      <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M10.293 3.293a1 1 0 011.414 0l6 6a1 1 0 010 1.414l-6 6a1 1 0 01-1.414-1.414L14.586 11H3a1 1 0 110-2h11.586l-4.293-4.293a1 1 0 010-1.414z" clip-rule="evenodd" />
      </svg>
    SVG
  end
end
