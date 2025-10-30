# frozen_string_literal: true

# Component for displaying a GitHub issue comment
class IssueCommentComponent < ViewComponent::Base
  def initialize(comment:)
    @comment = comment
  end

  def call
    tag.div(class: "border border-gray-200 dark:border-gray-700 rounded-lg overflow-hidden") do
      safe_join([
        comment_header,
        comment_body
      ])
    end
  end

  private

  def comment_header
    tag.div(class: "bg-gray-50 dark:bg-gray-800 px-4 py-3 border-b border-gray-200 dark:border-gray-700") do
      tag.div(class: "flex items-center gap-3") do
        safe_join([
          author_avatar,
          author_info
        ])
      end
    end
  end

  def author_avatar
    return unless @comment.author_avatar_url

    render AvatarComponent.new(
      src: @comment.author_avatar_url,
      alt: @comment.author_login || "User",
      size: :small
    )
  end

  def author_info
    tag.div(class: "flex-1 min-w-0") do
      safe_join([
        author_name,
        tag.span(" commented ", class: "text-gray-500 dark:text-gray-400 text-sm"),
        comment_timestamp
      ])
    end
  end

  def author_name
    login = @comment.author_login || "Unknown"
    tag.span(login, class: "font-semibold text-gray-900 dark:text-white")
  end

  def comment_timestamp
    return unless @comment.github_created_at

    tag.span(class: "text-gray-500 dark:text-gray-400 text-sm") do
      time_ago_in_words(@comment.github_created_at) + " ago"
    end
  end

  def comment_body
    tag.div(class: "px-4 py-4") do
      tag.div(class: "prose prose-sm dark:prose-invert max-w-none prose-pre:bg-gray-100 dark:prose-pre:bg-gray-900 prose-code:text-pink-600 dark:prose-code:text-pink-400") do
        helpers.render_markdown(@comment.body || "")
      end
    end
  end
end
