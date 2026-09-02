# frozen_string_literal: true

# Renders one file's full contents at a pull request's head revision.
#
# Markdown is rendered the way issue bodies are; everything else is shown as
# source with line numbers. Binary files and blobs GitHub declines to inline
# get an explanation instead, since there is nothing useful to display.
class FileContentComponent < ViewComponent::Base
  # Extensions CommonMarker should be given rather than showing raw source.
  MARKDOWN_EXTENSIONS = %w[md markdown mdown mkd mkdn].freeze

  # File extension to Prism language, for the languages the layout loads.
  # Anything absent renders as plain text rather than guessing wrong.
  LANGUAGES = {
    "rb" => "ruby", "rake" => "ruby", "gemspec" => "ruby", "ru" => "ruby",
    "erb" => "erb",
    "js" => "javascript", "mjs" => "javascript", "cjs" => "javascript", "jsx" => "jsx",
    "ts" => "typescript", "tsx" => "tsx",
    "py" => "python",
    "sh" => "bash", "bash" => "bash", "zsh" => "bash",
    "yml" => "yaml", "yaml" => "yaml",
    "json" => "json",
    "sql" => "sql",
    "css" => "css", "scss" => "css",
    "html" => "markup", "xml" => "markup", "svg" => "markup",
    "go" => "go",
    "tf" => "hcl", "hcl" => "hcl",
    "md" => "markdown", "markdown" => "markdown"
  }.freeze

  # Filenames with no useful extension that still have an obvious language.
  FILENAME_LANGUAGES = {
    "gemfile" => "ruby", "rakefile" => "ruby", "guardfile" => "ruby",
    "dockerfile" => "docker", "makefile" => "makefile"
  }.freeze

  # Callers outside the component need this to decide whether a Rendered/Source
  # toggle is worth offering.
  def self.markdown?(path)
    MARKDOWN_EXTENSIONS.include?(File.extname(path.to_s).delete_prefix(".").downcase)
  end

  attr_reader :file, :path

  # `raw` forces the source view for a file that would otherwise be rendered,
  # backing the Rendered/Source toggle.
  # :reek:BooleanParameter - Which of two presentations to use is inherently a yes/no
  def initialize(file:, path:, raw: false)
    @file = file
    @path = path.to_s
    @raw = raw
    super()
  end

  def extension
    File.extname(path).delete_prefix(".").downcase
  end

  def markdown?
    self.class.markdown?(path)
  end

  # The Prism language class for the source view, or nil to leave it plain.
  def language
    LANGUAGES[extension] || FILENAME_LANGUAGES[File.basename(path).downcase]
  end

  def code_classes
    language ? "language-#{language}" : "language-none"
  end

  def render_markdown?
    markdown? && !@raw
  end

  def binary?
    file[:binary].present?
  end

  def content
    file[:content].to_s
  end

  # Lines as the gutter counts them: a trailing newline terminates the last
  # line rather than starting a new empty one.
  def line_count
    return 0 if empty?

    newlines = content.count("\n")
    content.end_with?("\n") ? newlines : newlines + 1
  end

  def size
    file[:size].to_i
  end

  # A file consisting only of a trailing newline splits into one empty line,
  # which would render as a stray numbered blank rather than "empty".
  def empty?
    content.empty?
  end
end
