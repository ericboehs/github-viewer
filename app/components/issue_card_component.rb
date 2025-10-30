# frozen_string_literal: true

# Component for displaying a GitHub issue card in list view
class IssueCardComponent < ViewComponent::Base
  def initialize(issue:, repository:)
    @issue = issue
    @repository = repository
  end

  def call
    tag.div(class: "issue-card border-b border-gray-200 dark:border-gray-700 py-4 hover:bg-gray-50 dark:hover:bg-gray-800/50 transition-colors") do
      safe_join([
        issue_header,
        issue_metadata
      ])
    end
  end

  private

  def issue_header
    tag.div(class: "flex items-start gap-3") do
      safe_join([
        issue_icon,
        issue_content
      ])
    end
  end

  def issue_icon
    tag.div(class: "flex-shrink-0 pt-1") do
      render IssueStateComponent.new(state: @issue.state)
    end
  end

  def issue_content
    tag.div(class: "flex-1 min-w-0") do
      safe_join([
        issue_title,
        issue_labels
      ])
    end
  end

  def issue_title
    link_to repository_issue_path(@repository, @issue.number),
            class: "text-base font-semibold text-gray-900 dark:text-white hover:text-blue-600 dark:hover:text-blue-400" do
      @issue.title
    end
  end

  def issue_labels
    labels = @issue.labels
    return if labels.blank?

    tag.div(class: "flex flex-wrap gap-1 mt-2") do
      labels.map { |label| render IssueLabelComponent.new(label: label) }.join.html_safe
    end
  end

  def issue_metadata
    tag.div(class: "mt-2 ml-8 flex items-center gap-2 text-sm text-gray-500 dark:text-gray-400") do
      safe_join([
        issue_number,
        author_info,
        timestamp
      ].compact, tag.span("·", class: "text-gray-400 dark:text-gray-500"))
    end
  end

  def issue_number
    tag.span("##{@issue.number}", class: "font-mono")
  end

  def author_info
    author_login = @issue.author_login
    created_at = @issue.github_created_at
    return unless author_login && created_at

    tag.span do
      concat tag.span(author_login, class: "font-medium")
      concat " opened "
      concat helpers.time_ago_tag(created_at)
    end
  end

  def timestamp
    updated_at = @issue.github_updated_at
    return unless updated_at

    tag.span do
      concat "Updated "
      concat helpers.time_ago_tag(updated_at)
    end
  end
end
