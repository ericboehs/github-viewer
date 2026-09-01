# frozen_string_literal: true

# Component for displaying timeline events (labels, milestones, projects, comments)
# :reek:TooManyInstanceVariables - Extracts data from item hash for view access
# :reek:TooManyMethods - One predicate/accessor per timeline event shape
class TimelineEventComponent < ViewComponent::Base
  def initialize(item:, repository: nil)
    @item = item
    @type = item[:type]
    @repository = repository
  end

  def render?
    return false if @item.blank?

    # An empty "commented" review is pure noise: GitHub emits one to carry
    # inline comments, so with no body and no comments there is nothing to say.
    return false if empty_review?

    true
  end

  private

  def is_comment?
    @type == "comment"
  end

  def review?
    @type == "review"
  end

  def review_comments
    @item[:comments] || []
  end

  # A review worth its own card: it has a summary body, inline comments, or both.
  def detailed_review?
    review? && (@item[:body].present? || review_comments.any?)
  end

  def empty_review?
    review? && @item[:body].blank? && review_comments.empty? &&
      @item[:review_state].to_s.in?(%w[COMMENTED PENDING])
  end

  # We only request the first page of inline comments; say so rather than
  # quietly showing a partial thread.
  def hidden_comment_count
    shown = review_comments.size
    total = @item[:comments_total] || shown
    [ total - shown, 0 ].max
  end

  # :reek:TooManyStatements - Simple case statement mapping event types to icons
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
    when "merged", "ready_for_review", "review_requested", "review"
      pull_request_icon
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
    when "merged"
      "merged this pull request into"
    when "ready_for_review"
      "marked this pull request ready for review"
    when "review_requested"
      "requested a review from"
    when "review"
      review_text
    else
      ""
    end
  end

  def review_text
    case @item[:review_state]
    when "APPROVED" then "approved these changes"
    when "CHANGES_REQUESTED" then "requested changes"
    when "DISMISSED" then "had their review dismissed"
    else "reviewed these changes"
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

  # :reek:UtilityFunction - Static SVG helper, appropriate as private method
  def pull_request_icon
    <<~SVG.html_safe
      <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 16 16">
        <path d="M1.5 3.25a2.25 2.25 0 1 1 3 2.122v5.256a2.251 2.251 0 1 1-1.5 0V5.372A2.25 2.25 0 0 1 1.5 3.25Zm5.677-.177L9.573.677A.25.25 0 0 1 10 .854V2.5h1A2.5 2.5 0 0 1 13.5 5v5.628a2.251 2.251 0 1 1-1.5 0V5a1 1 0 0 0-1-1h-1v1.646a.25.25 0 0 1-.427.177L7.177 3.427a.25.25 0 0 1 0-.354ZM3.75 2.5a.75.75 0 1 0 0 1.5.75.75 0 0 0 0-1.5Zm0 9.5a.75.75 0 1 0 0 1.5.75.75 0 0 0 0-1.5Zm8.25.75a.75.75 0 1 0 1.5 0 .75.75 0 0 0-1.5 0Z" />
      </svg>
    SVG
  end
end
