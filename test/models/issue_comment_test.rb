require "test_helper"

# Tests for IssueComment model validations, associations, and ordering
class IssueCommentTest < ActiveSupport::TestCase
  setup do
    @issue = issues(:one)
    @comment = issue_comments(:one)
  end

  test "should be valid with valid attributes" do
    comment = IssueComment.new(
      issue: @issue,
      github_id: 999999,
      body: "Test comment"
    )
    assert comment.valid?
  end

  test "should require github_id" do
    @comment.github_id = nil
    assert_not @comment.valid?
    assert_includes @comment.errors[:github_id], "can't be blank"
  end

  test "should belong to issue" do
    assert_equal @issue, @comment.issue
  end

  test "should enforce unique github_id per issue" do
    duplicate = IssueComment.new(
      issue: @issue,
      github_id: @comment.github_id,
      body: "Duplicate"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:github_id], "has already been taken"
  end

  test "should allow same github_id for different issues" do
    other_issue = issues(:two)
    comment = IssueComment.new(
      issue: other_issue,
      github_id: @comment.github_id,
      body: "Different issue"
    )
    assert comment.valid?
  end

  test "should order by github_created_at ascending" do
    comments = IssueComment.all.to_a
    assert_equal comments.first.github_created_at, @comment.github_created_at
  end
end
