# frozen_string_literal: true

require "test_helper"

# Tests FileDiffComponent, which renders one file's entry in the Files changed
# tab including the unified diff parsing
class FileDiffComponentTest < ViewComponent::TestCase
  test "renders the filename, status badge and diffstat" do
    render_inline(FileDiffComponent.new(file: file_data))

    assert_text "app/models/issue.rb"
    assert_text "modified"
    assert_text "+2"
    assert_text "1"
  end

  test "renders a rename with the previous filename" do
    render_inline(FileDiffComponent.new(file: file_data(
      status: "renamed",
      previous_filename: "app/models/old_issue.rb"
    )))

    assert_text "app/models/old_issue.rb"
    assert_text "app/models/issue.rb"
  end

  test "styles each status distinctly and falls back for unknown ones" do
    FileDiffComponent::STATUS_CLASSES.each_key do |status|
      component = FileDiffComponent.new(file: file_data(status: status))

      assert_equal FileDiffComponent::STATUS_CLASSES.fetch(status), component.status_classes
    end

    unknown = FileDiffComponent.new(file: file_data(status: "copied"))

    assert_equal FileDiffComponent::DEFAULT_STATUS_CLASSES, unknown.status_classes
  end

  # The parser has to track two independent counters, because additions do not
  # advance the old-file number and deletions do not advance the new one.
  test "numbers diff lines against the correct side of the hunk" do
    patch = "@@ -10,3 +20,4 @@\n unchanged\n-removed\n+added one\n+added two"

    rows = FileDiffComponent.new(file: file_data(patch: patch)).rows

    assert_equal :hunk, rows[0][:kind]
    assert_nil rows[0][:old_number]

    assert_equal [ :context, 10, 20 ], rows[1].values_at(:kind, :old_number, :new_number)
    assert_equal [ :deletion, 11, nil ], rows[2].values_at(:kind, :old_number, :new_number)
    assert_equal [ :addition, nil, 21 ], rows[3].values_at(:kind, :old_number, :new_number)
    assert_equal [ :addition, nil, 22 ], rows[4].values_at(:kind, :old_number, :new_number)
  end

  test "reads the starting line numbers from a hunk header without counts" do
    rows = FileDiffComponent.new(file: file_data(patch: "@@ -5 +7 @@\n context")).rows

    assert_equal [ :context, 5, 7 ], rows[1].values_at(:kind, :old_number, :new_number)
  end

  test "restarts numbering at each hunk header" do
    patch = "@@ -1,1 +1,1 @@\n first\n@@ -50,1 +60,1 @@\n second"

    rows = FileDiffComponent.new(file: file_data(patch: patch)).rows

    assert_equal 1, rows[1][:old_number]
    assert_equal 50, rows[3][:old_number]
    assert_equal 60, rows[3][:new_number]
  end

  test "renders diff rows into a table" do
    render_inline(FileDiffComponent.new(file: file_data(patch: "@@ -1,1 +1,2 @@\n kept\n+gained")))

    assert_selector "table tbody tr", count: 3
    assert_text "+gained"
  end

  test "returns no rows when there is no patch" do
    assert_empty FileDiffComponent.new(file: file_data(patch: nil)).rows
  end

  # GitHub omits `patch` both for binary files and for oversized diffs, and the
  # two deserve different explanations. `changes` is the only signal available
  # to tell them apart: a binary file reports no line changes.
  test "explains a binary file when there is no patch and no line changes" do
    render_inline(FileDiffComponent.new(file: file_data(patch: nil, changes: 0)))

    assert_text I18n.t("pulls.files.binary_file")
    assert_no_selector "table"
  end

  test "explains an oversized diff when there is no patch but there are line changes" do
    render_inline(FileDiffComponent.new(file: file_data(patch: nil, changes: 5000)))

    assert_text I18n.t("pulls.files.diff_too_large")
  end

  test "reports no reason when a patch is present" do
    assert_nil FileDiffComponent.new(file: file_data).no_patch_reason
  end

  test "styles additions, deletions, hunks and context differently" do
    component = FileDiffComponent.new(file: file_data)

    assert_equal FileDiffComponent::LINE_CLASSES[:addition], component.line_classes(:addition)
    assert_equal FileDiffComponent::LINE_CLASSES[:deletion], component.line_classes(:deletion)
    assert_equal FileDiffComponent::LINE_CLASSES[:hunk], component.line_classes(:hunk)
    assert_equal "", component.line_classes(:context)
    assert_equal "", component.line_classes(:unknown)
  end

  private

  def file_data(**overrides)
    {
      filename: "app/models/issue.rb",
      previous_filename: nil,
      status: "modified",
      additions: 2,
      deletions: 1,
      changes: 3,
      patch: "@@ -1,2 +1,3 @@\n context\n+added\n-removed"
    }.merge(overrides)
  end

  # The +/- is diff syntax, not source. Leaving it attached makes Prism lex the
  # first token of every changed line wrong.
  test "splits the diff marker from the code" do
    patch = "@@ -1,2 +1,2 @@\n-old_value = 1\n+new_value = 2\n unchanged = 3"
    rows = FileDiffComponent.new(file: file_data(patch: patch)).rows

    assert_equal [ "", "-", "+", " " ], rows.map { |row| row[:marker] }
    assert_equal [
      "@@ -1,2 +1,2 @@", "old_value = 1", "new_value = 2", "unchanged = 3"
    ], rows.map { |row| row[:code] }
  end

  # A bare blank line and the no-newline marker have no leading space to strip.
  test "passes through lines with no diff marker" do
    patch = "@@ -1,1 +1,1 @@\n\n\\ No newline at end of file"
    rows = FileDiffComponent.new(file: file_data(patch: patch)).rows

    assert_equal [ "", "", "" ], rows.map { |row| row[:marker] }
    assert_equal "\\ No newline at end of file", rows.last[:code]
  end

  test "derives the Prism language from the filename" do
    assert_equal "ruby", FileDiffComponent.new(file: file_data).language
    assert_nil FileDiffComponent.new(file: file_data(filename: "notes.xyz")).language
  end

  test "marks code lines for highlighting but not hunk headers" do
    patch = "@@ -1,1 +1,1 @@\n+x = 1"
    render_inline(FileDiffComponent.new(file: file_data(patch: patch)))

    assert_selector "[data-syntax-highlight-language-value=ruby]"
    # One target: the added line, not the hunk header.
    assert_selector "[data-syntax-highlight-target=line]", count: 1, text: "x = 1"
    assert_text "@@ -1,1 +1,1 @@"
  end
end
