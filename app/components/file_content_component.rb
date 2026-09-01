# frozen_string_literal: true

# Renders one file's full contents at a pull request's head revision.
#
# Markdown is rendered the way issue bodies are; everything else is shown as
# source with line numbers. Binary files and blobs GitHub declines to inline
# get an explanation instead, since there is nothing useful to display.
class FileContentComponent < ViewComponent::Base
  # Extensions CommonMarker should be given rather than showing raw source.
  MARKDOWN_EXTENSIONS = %w[md markdown mdown mkd mkdn].freeze

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

  def render_markdown?
    markdown? && !@raw
  end

  def binary?
    file[:binary].present?
  end

  def content
    file[:content].to_s
  end

  # Source view needs the lines split anyway, and an empty file has none.
  def lines
    content.split("\n", -1)
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
