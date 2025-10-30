# frozen_string_literal: true

# Helper for rendering GitHub-flavored markdown
module MarkdownHelper
  # Renders markdown text to HTML with GitHub-flavored markdown extensions
  # @param text [String] The markdown text to render
  # @return [ActiveSupport::SafeBuffer] HTML-safe rendered markdown
  def render_markdown(text)
    return "" if text.blank?

    # Parse with GFM and syntax highlighting, allowing raw HTML like GitHub
    options = {
      parse: {
        smart: true
      },
      render: {
        unsafe: true,  # Allow raw HTML like GitHub does
        github_pre_lang: true  # Add language class to code blocks
      },
      extension: {
        strikethrough: true,
        tagfilter: true,
        table: true,
        autolink: true,
        tasklist: true
      }
    }

    Commonmarker.to_html(text, options: options).html_safe
  end
end
