# frozen_string_literal: true

require "test_helper"

# Tests FileContentComponent, which shows one file's full contents as rendered
# markdown, as numbered source, or as an explanation when neither is possible
class FileContentComponentTest < ViewComponent::TestCase
  test "renders markdown files through the markdown pipeline" do
    render_inline(build_component(path: "README.md", content: "# Title\n\nSome **bold** text."))

    assert_selector "div.markdown h1", text: "Title"
    assert_selector "div.markdown strong", text: "bold"
    assert_no_selector "table"
  end

  test "recognizes every markdown extension" do
    FileContentComponent::MARKDOWN_EXTENSIONS.each do |extension|
      assert FileContentComponent.markdown?("notes.#{extension}"), "expected .#{extension} to be markdown"
    end
  end

  test "treats extensions case insensitively" do
    assert FileContentComponent.markdown?("README.MD")
  end

  test "does not treat source files as markdown" do
    refute FileContentComponent.markdown?("app/models/issue.rb")
    refute FileContentComponent.markdown?("Makefile")
  end

  test "renders non-markdown files as numbered source" do
    render_inline(build_component(path: "app/models/issue.rb", content: "class Issue\nend"))

    assert_selector "table tbody tr", count: 2
    assert_text "class Issue"
    assert_no_selector "div.markdown"
  end

  # The toggle has to be able to show a markdown file's source without the
  # component deciding to render it anyway.
  test "shows markdown source when raw is requested" do
    render_inline(build_component(path: "README.md", content: "# Title", raw: true))

    assert_selector "table tbody tr", count: 1
    assert_text "# Title"
    assert_no_selector "div.markdown h1"
  end

  test "still reports a raw markdown file as markdown so the toggle stays visible" do
    component = build_component(path: "README.md", content: "# Title", raw: true)

    assert component.markdown?
    refute component.render_markdown?
  end

  test "explains a binary file rather than rendering bytes" do
    render_inline(build_component(path: "logo.png", content: nil, binary: true))

    assert_text I18n.t("pulls.files.binary_file")
    assert_no_selector "table"
  end

  test "explains an empty file rather than showing a blank numbered line" do
    render_inline(build_component(path: "empty.rb", content: ""))

    assert_text I18n.t("pulls.file.empty")
    assert_no_selector "table"
  end

  # Splitting with a -1 limit keeps trailing blank lines, so the line count
  # matches what an editor would show.
  test "keeps trailing blank lines in the source view" do
    component = build_component(path: "trailing.rb", content: "one\ntwo\n")

    assert_equal [ "one", "two", "" ], component.lines
  end

  test "shows the file path and human readable size" do
    render_inline(build_component(path: "app/models/issue.rb", content: "x", size: 2048))

    assert_text "app/models/issue.rb"
    assert_text "2 KB"
  end

  private

  def build_component(path:, content:, binary: false, size: 100, raw: false)
    FileContentComponent.new(
      file: { path: path, size: size, binary: binary, content: content },
      path: path,
      raw: raw
    )
  end
end
