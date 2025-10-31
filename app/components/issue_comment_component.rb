# frozen_string_literal: true

# Component for displaying a GitHub issue comment
class IssueCommentComponent < ViewComponent::Base
  def initialize(comment:)
    @comment = comment
  end

  def call
    tag.div(class: "border border-blue-200 dark:border-gray-700 rounded-lg overflow-hidden bg-white dark:bg-black") do
      safe_join([
        comment_header,
        comment_body
      ])
    end
  end

  private

  def comment_header
    tag.div(class: "bg-blue-50 dark:bg-gray-900 px-4 py-3 border-b border-blue-200 dark:border-gray-700") do
      author_info
    end
  end

  def author_info
    tag.div(class: "flex items-center gap-2") do
      safe_join([
        author_avatar,
        author_name,
        tag.span(" commented ", class: "text-gray-500 dark:text-gray-400 text-sm"),
        comment_timestamp
      ].compact)
    end
  end

  def author_avatar
    avatar_url = @comment.author_avatar_url
    return unless avatar_url

    render AvatarComponent.new(
      src: avatar_url,
      alt: @comment.author_login || "User",
      size: :small
    )
  end

  def author_name
    login = @comment.author_login || "Unknown"
    tag.span(login, class: "font-semibold text-gray-900 dark:text-white")
  end

  def comment_timestamp
    created_at = @comment.github_created_at
    return unless created_at

    helpers.time_ago_tag(created_at, class: "text-gray-500 dark:text-gray-400 text-sm")
  end

  def comment_body
    tag.div(class: "px-4 py-4 bg-white dark:bg-black") do
      tag.div(class: "markdown text-gray-900 dark:text-gray-200") do
        helpers.render_markdown(@comment.body || "")
      end
    end
  end
end
