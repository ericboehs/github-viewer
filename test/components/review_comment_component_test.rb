# frozen_string_literal: true

require "test_helper"

class ReviewCommentComponentTest < ViewComponent::TestCase
  def comment(**overrides)
    {
      id: "c1",
      body: "Consider extracting this.",
      path: "app/services/github/api_client.rb",
      diff_hunk: "@@ -1,6 +1,7 @@\n context one\n context two\n-removed line\n+added line",
      outdated: false,
      line: 42,
      created_at: Time.current,
      actor: "reviewer",
      avatar_url: "https://example.com/avatar.png"
    }.merge(overrides)
  end

  test "renders the file, line, author and body" do
    render_inline(ReviewCommentComponent.new(comment: comment))

    assert_text "app/services/github/api_client.rb"
    assert_text "line 42"
    assert_text "reviewer"
    assert_text "Consider extracting this."
  end

  test "renders the diff hunk without its header" do
    render_inline(ReviewCommentComponent.new(comment: comment))

    assert_text "added line"
    assert_text "removed line"
    assert_no_text "@@ -1,6 +1,7 @@"
  end

  test "keeps only the trailing context lines of a long hunk" do
    hunk = (1..20).map { |n| " line #{n}" }.join("\n")
    render_inline(ReviewCommentComponent.new(comment: comment(diff_hunk: hunk)))

    assert_text "line 20"
    assert_no_text "line 1 "
  end

  test "colours additions, deletions and context differently" do
    component = ReviewCommentComponent.new(comment: comment)

    assert_equal ReviewCommentComponent::ADDITION_CLASSES, component.line_classes("+new")
    assert_equal ReviewCommentComponent::DELETION_CLASSES, component.line_classes("-old")
    assert_equal ReviewCommentComponent::CONTEXT_CLASSES, component.line_classes(" same")
  end

  test "omits the diff when there is no hunk" do
    render_inline(ReviewCommentComponent.new(comment: comment(diff_hunk: nil)))

    assert_text "Consider extracting this."
    assert_no_selector "table"
  end

  test "omits the line number when the comment has none" do
    render_inline(ReviewCommentComponent.new(comment: comment(line: nil)))

    assert_no_text "line "
  end

  test "flags an outdated comment" do
    render_inline(ReviewCommentComponent.new(comment: comment(outdated: true)))

    assert_text "Outdated"
  end

  test "does not flag a current comment" do
    render_inline(ReviewCommentComponent.new(comment: comment))

    assert_no_text "Outdated"
  end
end
