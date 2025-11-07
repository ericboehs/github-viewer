# frozen_string_literal: true

# Component for displaying a GitHub issue card in list view
# :reek:TooManyMethods - Component breaks down rendering into focused, single-responsibility methods
class IssueCardComponent < ViewComponent::Base
  def initialize(issue:, repository:)
    @issue = issue
    @repository = repository
  end

  def call
    tag.div(class: "issue-card px-4 sm:px-6 py-2 hover:bg-gray-50 dark:hover:bg-gray-800/50 transition-colors") do
      issue_header
    end
  end

  private

  def issue_header
    tag.div(class: "flex items-start gap-2") do
      safe_join([
        issue_icon,
        issue_content,
        issue_actions
      ])
    end
  end

  def issue_icon
    tag.div(class: "flex-shrink-0 flex items-center mr-1") do
      render IssueStateComponent.new(state: @issue.state)
    end
  end

  def issue_content
    tag.div(class: "flex-1 min-w-0") do
      safe_join([
        issue_title_row,
        issue_actions_mobile,
        issue_metadata
      ])
    end
  end

  def issue_title_row
    tag.div do
      safe_join([
        issue_title,
        issue_labels
      ].compact, " ")
    end
  end

  def issue_title
    link_to repository_issue_path(@repository, @issue.number),
            class: "text-base font-semibold text-gray-900 dark:text-white hover:text-blue-600 dark:hover:text-blue-500 hover:underline break-all" do
      @issue.title
    end
  end

  def issue_labels
    labels = @issue.labels
    return if labels.blank?

    tag.span(class: "inline-flex flex-wrap gap-1 align-middle") do
      labels.map do |label|
        render IssueLabelComponent.new(
          label: label,
          repository: @repository,
          query: helpers.params[:q]
        )
      end.join.html_safe
    end
  end

  def issue_actions
    tag.div(class: "hidden sm:flex items-center gap-3 flex-shrink-0") do
      safe_join([
        comment_count,
        assignee_avatars
      ].compact)
    end
  end

  def issue_actions_mobile
    tag.div(class: "flex sm:hidden items-center gap-3 mt-2") do
      safe_join([
        comment_count,
        assignee_avatars
      ].compact)
    end
  end

  def comment_count
    comments = @issue.issue_comments.count

    tag.div(class: "flex items-center gap-1 text-gray-500 dark:text-gray-400 text-sm") do
      safe_join([
        tag.svg(class: "w-4 h-4", fill: "currentColor", viewBox: "0 0 16 16") do
          tag.path(d: "M2.678 11.894a1 1 0 0 1 .287.801 11 11 0 0 1-.398 2c1.395-.323 2.247-.697 2.634-.893a1 1 0 0 1 .71-.074A8 8 0 0 0 8 14c3.996 0 7-2.807 7-6s-3.004-6-7-6-7 2.808-7 6c0 1.468.617 2.83 1.678 3.894m-.493 3.905a22 22 0 0 1-.713.129c-.2.032-.352-.176-.273-.362a10 10 0 0 0 .244-.637l.003-.01c.248-.72.45-1.548.524-2.319C.743 11.37 0 9.76 0 8c0-3.866 3.582-7 8-7s8 3.134 8 7-3.582 7-8 7a9 9 0 0 1-2.347-.306c-.52.263-1.639.742-3.468 1.105")
        end,
        tag.span(comments.to_s)
      ])
    end
  end

  # :reek:TooManyStatements - Rendering assignee avatars requires multiple view operations
  def assignee_avatars
    assignees = @issue.assignees
    return if assignees.blank?

    tag.div(class: "flex -space-x-1") do
      assignees.first(3).map do |assignee|
        avatar_url = assignee["avatar_url"] || assignee[:avatar_url]
        login = assignee["login"] || assignee[:login]

        # Build query with assignee filter and trailing space
        current_query = helpers.params[:q] || ""
        query_without_assignee = current_query.gsub(/\bassignee:("[^"]*"|\S+)/i, "").gsub(/\s+/, " ").strip
        new_query = query_without_assignee.present? ? "#{query_without_assignee} assignee:#{login} " : "assignee:#{login} "

        link_to helpers.repository_issues_path(@repository, q: new_query), class: "relative group block" do
          safe_join([
            render(AvatarComponent.new(
              src: avatar_url,
              alt: login,
              size: :small
            )),
            tag.div(class: "absolute bottom-full left-1/2 -translate-x-1/2 mb-2 px-3 py-1.5 text-xs font-medium text-white bg-gray-900 dark:bg-gray-700 rounded-md whitespace-nowrap opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none z-10") do
              safe_join([
                tag.span(login),
                tag.div(class: "absolute top-full left-1/2 -translate-x-1/2 -mt-1") do
                  tag.div(class: "border-4 border-transparent border-t-gray-900 dark:border-t-gray-700")
                end
              ])
            end
          ])
        end
      end.join.html_safe
    end
  end

  def issue_metadata
    tag.div(class: "mt-1 flex items-center gap-2 text-sm text-gray-500 dark:text-gray-400") do
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

  # :reek:TooManyStatements - Building author info requires multiple concatenations
  def author_info
    author_login = @issue.author_login
    created_at = @issue.github_created_at
    return unless author_login && created_at

    # Build query with author filter and trailing space
    current_query = helpers.params[:q] || ""
    query_without_author = current_query.gsub(/\bauthor:("[^"]*"|\S+)/i, "").gsub(/\s+/, " ").strip
    new_query = query_without_author.present? ? "#{query_without_author} author:#{author_login} " : "author:#{author_login} "

    tag.span do
      concat link_to(author_login, helpers.repository_issues_path(@repository, q: new_query), class: "font-medium hover:text-gray-700 dark:hover:text-gray-300")
      concat " opened "
      concat helpers.time_ago_tag(created_at)
    end
  end

  def timestamp
    updated_at = @issue.github_updated_at
    return unless updated_at

    tag.span(class: "hidden sm:inline") do
      concat "Updated "
      concat helpers.time_ago_tag(updated_at)
    end
  end
end
