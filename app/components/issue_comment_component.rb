# frozen_string_literal: true

# Component for displaying a GitHub issue comment
class IssueCommentComponent < ViewComponent::Base
  def initialize(comment:)
    @comment = comment
  end

  def call
    tag.div(class: "border border-gray-200 dark:border-gray-700 rounded-lg overflow-hidden bg-white dark:bg-black") do
      safe_join([
        comment_header,
        debug_toggle,
        comment_body,
        raw_markdown
      ])
    end
  end

  private

  def comment_header
    tag.div(class: "bg-gray-50 dark:bg-gray-900 px-4 py-3 border-b border-gray-200 dark:border-gray-700") do
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

  def debug_toggle
    tag.div(class: "px-4 pt-2 flex justify-end bg-gray-50 dark:bg-gray-900") do
      tag.button(
        onclick: "document.getElementById('comment-raw-#{@comment.id}').classList.toggle('hidden')",
        class: "text-xs px-2 py-1 rounded border border-gray-300 dark:border-gray-600 text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-700"
      ) do
        safe_join([
          tag.svg(class: "inline w-3 h-3 mr-1", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24", xmlns: "http://www.w3.org/2000/svg") do
            tag.path("stroke-linecap": "round", "stroke-linejoin": "round", "stroke-width": "2", d: "M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4")
          end,
          "Toggle Raw"
        ])
      end
    end
  end

  def comment_body
    tag.div(class: "px-4 py-4 bg-white dark:bg-black") do
      tag.div(class: "markdown text-gray-900 dark:text-gray-200") do
        helpers.render_markdown(@comment.body || "")
      end
    end
  end

  def raw_markdown
    return if @comment.body.blank?

    tag.div(id: "comment-raw-#{@comment.id}", class: "hidden px-4 pb-4 bg-white dark:bg-black") do
      safe_join([
        tag.h4("Raw Markdown", class: "text-sm font-semibold text-gray-700 dark:text-gray-300 mb-2"),
        tag.pre(@comment.body, class: "text-xs bg-gray-50 dark:bg-gray-900 p-4 rounded border border-gray-300 dark:border-gray-600 overflow-x-auto text-gray-900 dark:text-gray-200")
      ])
    end
  end
end
