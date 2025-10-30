# frozen_string_literal: true

# Component for displaying a GitHub issue card in list view
class IssueCardComponent < ViewComponent::Base
  def initialize(issue:, repository:)
    @issue = issue
    @repository = repository
  end

  def call
    tag.div(class: "border-b border-gray-200 dark:border-gray-700 py-4 hover:bg-gray-50 dark:hover:bg-gray-800/50 transition-colors") do
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
    return if @issue.labels.blank?

    tag.div(class: "flex flex-wrap gap-1 mt-2") do
      @issue.labels.map { |label| render IssueLabelComponent.new(label: label) }.join.html_safe
    end
  end

  def issue_metadata
    tag.div(class: "mt-2 ml-8 flex items-center gap-4 text-sm text-gray-500 dark:text-gray-400") do
      safe_join([
        issue_number,
        author_info,
        comment_count,
        timestamp
      ].compact, tag.span("•", class: "text-gray-300 dark:text-gray-600"))
    end
  end

  def issue_number
    tag.span("##{@issue.number}", class: "font-mono")
  end

  def author_info
    return unless @issue.author_login

    tag.span do
      concat "opened by "
      concat tag.span(@issue.author_login, class: "font-medium")
    end
  end

  def comment_count
    return if @issue.comments_count.zero?

    tag.span(class: "flex items-center gap-1") do
      safe_join([
        comment_icon,
        tag.span(@issue.comments_count.to_s)
      ])
    end
  end

  def comment_icon
    tag.svg(class: "w-4 h-4", fill: "currentColor", viewBox: "0 0 16 16", xmlns: "http://www.w3.org/2000/svg") do
      tag.path(d: "M1 2.75C1 1.784 1.784 1 2.75 1h10.5c.966 0 1.75.784 1.75 1.75v7.5A1.75 1.75 0 0 1 13.25 12H9.06l-2.573 2.573A1.458 1.458 0 0 1 4 13.543V12H2.75A1.75 1.75 0 0 1 1 10.25Zm1.75-.25a.25.25 0 0 0-.25.25v7.5c0 .138.112.25.25.25h2a.75.75 0 0 1 .75.75v2.19l2.72-2.72a.749.749 0 0 1 .53-.22h4.5a.25.25 0 0 0 .25-.25v-7.5a.25.25 0 0 0-.25-.25Z")
    end
  end

  def timestamp
    return unless @issue.github_updated_at

    tag.span("updated #{time_ago_in_words(@issue.github_updated_at)} ago")
  end
end
