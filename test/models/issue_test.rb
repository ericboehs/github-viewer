require "test_helper"

# Tests for Issue model validations, associations, state management, and scopes
class IssueTest < ActiveSupport::TestCase
  setup do
    @repository = repositories(:one)
    @issue = issues(:one)
  end

  test "should be valid with valid attributes" do
    issue = Issue.new(
      repository: @repository,
      number: 999,
      title: "Test issue",
      state: "open"
    )
    assert issue.valid?
  end

  test "should require number" do
    @issue.number = nil
    assert_not @issue.valid?
    assert_includes @issue.errors[:number], "can't be blank"
  end

  test "should require title" do
    @issue.title = nil
    assert_not @issue.valid?
    assert_includes @issue.errors[:title], "can't be blank"
  end

  test "should require state" do
    @issue.state = nil
    assert_not @issue.valid?
    assert_includes @issue.errors[:state], "can't be blank"
  end

  test "should only allow open or closed state" do
    @issue.state = "invalid"
    assert_not @issue.valid?
    assert_includes @issue.errors[:state], "is not included in the list"
  end

  test "should belong to repository" do
    assert_equal @repository, @issue.repository
  end

  test "should have many issue_comments" do
    assert_respond_to @issue, :issue_comments
  end

  test "should enforce unique number per repository" do
    duplicate = Issue.new(
      repository: @repository,
      number: @issue.number,
      title: "Duplicate",
      state: "open"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:number], "has already been taken"
  end

  test "should allow same number for different repositories" do
    other_repo = repositories(:two)
    issue = Issue.new(
      repository: other_repo,
      number: @issue.number,
      title: "Different repo",
      state: "open"
    )
    assert issue.valid?
  end

  test "should return true for open?" do
    @issue.state = "open"
    assert @issue.open?
  end

  test "should return false for open? when closed" do
    @issue.state = "closed"
    assert_not @issue.open?
  end

  test "should return true for closed?" do
    @issue.state = "closed"
    assert @issue.closed?
  end

  test "should return false for closed? when open" do
    @issue.state = "open"
    assert_not @issue.closed?
  end

  test "should return open issues" do
    assert_includes Issue.open, @issue
  end

  test "should return closed issues" do
    closed_issue = issues(:two)
    assert_includes Issue.closed, closed_issue
  end

  test "should filter by state" do
    open_issues = Issue.by_state("open")
    assert_includes open_issues, @issue
  end

  test "should return label names" do
    expected_labels = [ "enhancement" ]
    assert_equal expected_labels, @issue.label_names
  end

  test "should return empty array for nil labels" do
    @issue.labels = nil
    assert_equal [], @issue.label_names
  end

  test "should return assignee logins" do
    expected_assignees = [ "dhh" ]
    assert_equal expected_assignees, @issue.assignee_logins
  end

  test "should return empty array for nil assignees" do
    @issue.assignees = nil
    assert_equal [], @issue.assignee_logins
  end

  test "should destroy dependent comments" do
    comment = @issue.issue_comments.create!(
      github_id: 999999,
      body: "Test comment"
    )
    comment_id = comment.id

    @issue.destroy

    assert_not IssueComment.exists?(comment_id)
  end

  test "should not filter by state when state is blank" do
    issues = Issue.by_state("")
    assert_equal Issue.count, issues.count
  end

  test "should filter with_label when label is present" do
    issues = Issue.with_label("enhancement")
    assert_includes issues, @issue
  end

  test "should not filter with_label when label is blank" do
    issues = Issue.with_label("")
    assert_equal Issue.count, issues.count
  end

  test "should filter assigned_to when login is present" do
    issues = Issue.assigned_to("dhh")
    assert_includes issues, @issue
  end

  test "should not filter assigned_to when login is blank" do
    issues = Issue.assigned_to("")
    assert_equal Issue.count, issues.count
  end

  test "should filter authored_by when login is present" do
    issues = Issue.authored_by("dhh")
    assert_includes issues, @issue
  end

  test "should not filter authored_by when login is blank" do
    issues = Issue.authored_by("")
    assert_equal Issue.count, issues.count
  end
end
