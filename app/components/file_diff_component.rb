# frozen_string_literal: true

# One file's entry in a pull request's Files changed tab: the header row with
# its status and diffstat, plus the unified diff rendered as a table.
#
# GitHub sends the diff as a raw unified patch string. It omits `patch`
# entirely for binary files and for diffs it deems too large, so a missing
# patch is an ordinary case rather than an error.
class FileDiffComponent < ViewComponent::Base
  STATUS_CLASSES = {
    "added" => "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-300",
    "removed" => "bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-300",
    "modified" => "bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-300",
    "renamed" => "bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-300"
  }.freeze
  DEFAULT_STATUS_CLASSES = "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300"

  # Line background and gutter styling keyed by the leading character of a
  # unified diff line.
  LINE_CLASSES = {
    addition: "bg-green-50 dark:bg-green-900/20",
    deletion: "bg-red-50 dark:bg-red-900/20",
    hunk: "bg-blue-50 text-blue-700 dark:bg-blue-900/20 dark:text-blue-300",
    context: ""
  }.freeze

  attr_reader :file, :repository, :issue

  def initialize(file:, repository: nil, issue: nil)
    @file = file
    @repository = repository
    @issue = issue
    super()
  end

  def filename
    file[:filename]
  end

  def previous_filename
    file[:previous_filename]
  end

  def status
    file[:status].to_s
  end

  def status_classes
    STATUS_CLASSES.fetch(status, DEFAULT_STATUS_CLASSES)
  end

  def additions
    file[:additions].to_i
  end

  def deletions
    file[:deletions].to_i
  end

  def patch
    file[:patch]
  end

  # A removed file has no contents at the head revision, so there is nothing
  # for the viewer to show and the name stays unlinked.
  def viewable?
    repository.present? && issue.present? && status != "removed"
  end

  def file_path
    file_repository_pull_path(repository, issue.number, path: filename)
  end

  # Explains an absent patch rather than rendering a blank panel, since the two
  # reasons GitHub omits one are worth telling apart.
  def no_patch_reason
    return if patch.present?

    # `I18n.t` rather than the component's own `t`, so the reason can be read
    # without first pushing the component through the render pipeline.
    file[:changes].to_i.zero? ? I18n.t("pulls.files.binary_file") : I18n.t("pulls.files.diff_too_large")
  end

  # Parses the unified patch into rows carrying their old and new line numbers,
  # so the table can show the same two gutters GitHub does.
  #
  # :reek:TooManyStatements - A line-by-line parser is inherently sequential
  # :reek:DuplicateMethodCall - Counters are read and incremented per row
  def rows
    return [] if patch.blank?

    old_line = new_line = 0

    patch.split("\n").map do |line|
      case line
      when /\A@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@/
        old_line = Regexp.last_match(1).to_i
        new_line = Regexp.last_match(2).to_i
        { kind: :hunk, text: line, old_number: nil, new_number: nil }
      when /\A\+/
        row = { kind: :addition, text: line, old_number: nil, new_number: new_line }
        new_line += 1
        row
      when /\A-/
        row = { kind: :deletion, text: line, old_number: old_line, new_number: nil }
        old_line += 1
        row
      else
        # Anything else is context, including the "\ No newline at end of file"
        # marker, which advances neither counter but is harmless to number.
        row = { kind: :context, text: line, old_number: old_line, new_number: new_line }
        old_line += 1
        new_line += 1
        row
      end
    end
  end

  # :reek:UtilityFunction - Maps a parsed line kind to its styling; belongs
  # with the rest of the diff presentation rather than in its own class
  def line_classes(kind)
    LINE_CLASSES.fetch(kind, "")
  end
end
