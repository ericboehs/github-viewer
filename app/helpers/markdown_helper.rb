# frozen_string_literal: true

# Helper for rendering GitHub-flavored markdown
module MarkdownHelper
  # Renders markdown text to HTML with GitHub-flavored markdown extensions
  # @param text [String] The markdown text to render
  # @return [ActiveSupport::SafeBuffer] HTML-safe rendered markdown
  def render_markdown(text)
    return "" if text.blank?

    # Use Commonmarker with GitHub-flavored markdown extensions
    doc = Commonmarker.to_html(text, options: {
      parse: {
        smart: true,
        default_info_string: "plaintext"
      },
      render: {
        hardbreaks: false,
        github_pre_lang: true,
        full_info_string: true,
        unsafe: false  # Sanitize HTML for security
      },
      extension: {
        strikethrough: true,
        tagfilter: true,
        table: true,
        autolink: true,
        tasklist: true,
        footnotes: true,
        description_lists: true,
        front_matter_delimiter: "---",
        shortcodes: false,
        spoiler: false
      }
    })

    sanitize_markdown_html(doc).html_safe
  end

  private

  # Sanitize HTML output from markdown rendering
  # Allows safe HTML tags that GitHub allows in markdown
  def sanitize_markdown_html(html)
    sanitize(html, tags: %w[
      h1 h2 h3 h4 h5 h6
      p br blockquote
      ul ol li
      a
      strong em del
      code pre
      table thead tbody tr th td
      input  # For task lists
      hr
      div span  # For certain markdown extensions
    ], attributes: %w[
      href
      title
      class
      type
      checked
      disabled  # For task lists
    ])
  end
end
