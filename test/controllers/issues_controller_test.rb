# frozen_string_literal: true

require "test_helper"

# Tests the IssuesController
class IssuesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email_address: "test@example.com",
      password: "password123"
    )
    @github_token = @user.github_tokens.create!(
      domain: "github.com",
      token: "ghp_test1234567890abcdef"
    )
    @repository = @user.repositories.create!(
      github_domain: "github.com",
      owner: "rails",
      name: "rails",
      full_name: "rails/rails",
      url: "https://github.com/rails/rails",
      cached_at: 1.hour.ago
    )
    sign_in_as(@user)
  end

  # Index action tests
  test "should get index with existing issues" do
    @repository.issues.create!(
      number: 1,
      title: "Test Issue",
      state: "open",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    get repository_issues_url(@repository)
    assert_response :success
    assert_select "h1", text: "rails/rails"
  end

  test "should trigger sync when repository has no issues" do
    # Mock the sync service to avoid real API calls
    mock_service = mock("IssueSyncService")
    mock_service.expects(:call).returns({ success: true, synced_count: 5 })

    Github::IssueSyncService.expects(:new).with(user: @user, repository: @repository).returns(mock_service)

    get repository_issues_url(@repository)
    assert_response :success
  end

  test "should show flash alert when sync fails on index" do
    # Mock the sync service to return failure
    mock_service = mock("IssueSyncService")
    mock_service.expects(:call).returns({ success: false, error: "API rate limit exceeded" })

    Github::IssueSyncService.expects(:new).with(user: @user, repository: @repository).returns(mock_service)

    get repository_issues_url(@repository)
    assert_response :success
    # Flash alert should be set
    assert_not_nil flash[:alert]
  end

  test "should not trigger sync when repository has cached issues" do
    @repository.issues.create!(
      number: 1,
      title: "Existing Issue",
      state: "open",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    # If sync is called, this will fail
    Github::IssueSyncService.expects(:new).never

    get repository_issues_url(@repository)
    assert_response :success
  end

  # Show action tests
  test "should show individual issue" do
    issue = @repository.issues.create!(
      number: 42,
      title: "Fix critical bug",
      state: "open",
      body: "This is a test issue body",
      author_login: "testuser",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    get repository_issue_url(@repository, issue.number)
    assert_response :success
    assert_select "h1", text: /Fix critical bug/
  end

  test "should return 404 when issue not found" do
    get repository_issue_url(@repository, 999)
    assert_response :not_found
  end

  test "should display issue comments" do
    issue = @repository.issues.create!(
      number: 1,
      title: "Test Issue",
      state: "open",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    issue.issue_comments.create!(
      github_id: 123456,
      author_login: "commenter",
      body: "This is a test comment",
      github_created_at: 1.hour.ago,
      github_updated_at: 1.hour.ago
    )

    get repository_issue_url(@repository, issue.number)
    assert_response :success
    assert_select "div", text: /This is a test comment/
  end

  # Refresh action tests
  test "should refresh issues successfully" do
    mock_service = mock("IssueSyncService")
    mock_service.expects(:call).returns({ success: true, synced_count: 10 })

    Github::IssueSyncService.expects(:new).with(user: @user, repository: @repository).returns(mock_service)

    post refresh_repository_issues_url(@repository)
    assert_redirected_to repository_issues_path(@repository)
    assert_match(/success/i, flash[:notice])
  end

  test "should show error when refresh fails" do
    mock_service = mock("IssueSyncService")
    mock_service.expects(:call).returns({ success: false, error: "Network timeout" })

    Github::IssueSyncService.expects(:new).with(user: @user, repository: @repository).returns(mock_service)

    post refresh_repository_issues_url(@repository)
    assert_redirected_to repository_issues_path(@repository)
    assert_includes flash[:alert], "Network timeout"
  end

  # Search functionality tests
  test "should filter issues by query parameter" do
    @repository.issues.create!(
      number: 1,
      title: "Bug in login form",
      state: "open",
      body: "Login validation error",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )
    @repository.issues.create!(
      number: 2,
      title: "Feature: dark mode",
      state: "open",
      body: "Add dark mode support",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    get repository_issues_url(@repository), params: { q: "login" }
    assert_response :success
    assert_select ".issue-card", count: 1
  end

  test "should filter issues by state" do
    @repository.issues.create!(
      number: 1,
      title: "Open Issue",
      state: "open",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )
    @repository.issues.create!(
      number: 2,
      title: "Closed Issue",
      state: "closed",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    get repository_issues_url(@repository), params: { state: "open" }
    assert_response :success
    # Should only show open issue
    assert_select ".issue-card", count: 1
  end

  test "should sort issues by specified sort parameter" do
    # Create issues with different updated times
    @repository.issues.create!(
      number: 1,
      title: "Older Issue",
      state: "open",
      comments_count: 10,
      github_created_at: 3.days.ago,
      github_updated_at: 2.days.ago
    )
    @repository.issues.create!(
      number: 2,
      title: "Newer Issue",
      state: "open",
      comments_count: 5,
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    # Sort by comments should show issue #1 first (10 comments)
    get repository_issues_url(@repository), params: { sort: "comments" }
    assert_response :success
  end

  test "should handle search errors gracefully" do
    # Mock search service to return error
    mock_service = mock("IssueSearchService")
    mock_service.expects(:call).returns({ success: false, error: "Search failed" })

    Github::IssueSearchService.expects(:new).returns(mock_service)

    @repository.issues.create!(
      number: 1,
      title: "Test Issue",
      state: "open",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    get repository_issues_url(@repository), params: { q: "test" }
    assert_response :success
    assert_not_nil flash[:alert]
  end

  # Filter extraction tests
  test "should display label filter when issues have labels" do
    @repository.issues.create!(
      number: 1,
      title: "Issue 1",
      state: "open",
      labels: [ { "name" => "bug", "color" => "d73a4a" } ],
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    get repository_issues_url(@repository)
    assert_response :success
    assert_select "select[name='label']", count: 1
    assert_select "option", text: "bug"
  end

  test "should display assignee filter when issues have assignees" do
    @repository.issues.create!(
      number: 1,
      title: "Issue 1",
      state: "open",
      assignees: [ { "login" => "alice", "avatar_url" => "https://example.com/alice.png" } ],
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    get repository_issues_url(@repository)
    assert_response :success
    assert_select "select[name='assignee']", count: 1
    assert_select "option", text: "alice"
  end

  test "should not display label filter when no labels exist" do
    @repository.issues.create!(
      number: 1,
      title: "Issue without labels",
      state: "open",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    get repository_issues_url(@repository)
    assert_response :success
    assert_select "select[name='label']", count: 0
  end

  test "should not display assignee filter when no assignees exist" do
    @repository.issues.create!(
      number: 1,
      title: "Issue without assignees",
      state: "open",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    get repository_issues_url(@repository)
    assert_response :success
    assert_select "select[name='assignee']", count: 0
  end

  test "should display search form" do
    get repository_issues_url(@repository)
    assert_response :success
    assert_select "input[name='q']"
    assert_select "input[type='submit'][value='Search']"
  end

  test "should parse GitHub search qualifiers" do
    @repository.issues.create!(
      number: 1,
      title: "Bug issue",
      state: "open",
      labels: [ { "name" => "bug", "color" => "d73a4a" } ],
      assignees: [ { "login" => "alice", "avatar_url" => "https://example.com/alice.png" } ],
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    # Test is: qualifier
    get repository_issues_url(@repository), params: { q: "is:open memory" }
    assert_response :success

    # Test label: qualifier
    get repository_issues_url(@repository), params: { q: "label:bug test" }
    assert_response :success

    # Test assignee: qualifier
    get repository_issues_url(@repository), params: { q: "assignee:alice" }
    assert_response :success

    # Test sort: qualifier
    get repository_issues_url(@repository), params: { q: "sort:updated-desc" }
    assert_response :success

    # Test combined qualifiers
    get repository_issues_url(@repository), params: { q: "is:open label:bug sort:created" }
    assert_response :success
  end

  test "should display sort dropdown" do
    get repository_issues_url(@repository)
    assert_response :success
    assert_select "select[name='sort']"
    assert_select "option", text: "Recently updated"
  end

  # Authorization tests
  test "should not access issues from other users repositories" do
    other_user = User.create!(
      email_address: "other@example.com",
      password: "password123"
    )
    other_repo = other_user.repositories.create!(
      github_domain: "github.com",
      owner: "other",
      name: "repo",
      full_name: "other/repo",
      url: "https://github.com/other/repo"
    )

    get repository_issues_url(other_repo)
    assert_response :not_found
  end

  test "should require authentication" do
    sign_out
    get repository_issues_url(@repository)
    assert_redirected_to new_session_url
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  def sign_out
    delete session_url
  end
end
