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

    get repository_issues_url(@repository), params: { q: "state:open" }
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
    # Create an issue to show as fallback
    @repository.issues.create!(
      number: 1,
      title: "Test Issue",
      state: "open",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    # Mock search service to return error for GitHub mode, then success for local mode
    mock_github_service = mock("GitHubIssueSearchService")
    mock_github_service.expects(:call).returns({ success: false, error: "Search failed" })

    mock_local_service = mock("LocalIssueSearchService")
    mock_local_service.expects(:call).returns({
      success: true,
      issues: @repository.issues.order(github_updated_at: :desc).to_a,
      mode: :local,
      count: 1
    })

    # Expect two calls to new - first for GitHub mode (fails), then for local mode (succeeds)
    Github::IssueSearchService.expects(:new).twice.returns(mock_github_service, mock_local_service)

    get repository_issues_url(@repository), params: { q: "test" }
    assert_response :success
    assert_not_nil flash[:alert]
  end

  # Filter extraction tests
  test "should display assignee filter dropdown when issues have assignees" do
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
    # Check for filter dropdown component
    assert_select "[data-controller='filter-dropdown']"
    assert_select "button", text: "Assignees"
  end

  test "should not display assignee filter dropdown when no assignees exist" do
    @repository.issues.create!(
      number: 1,
      title: "Issue without assignees",
      state: "open",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    get repository_issues_url(@repository)
    assert_response :success
    # Filter dropdown should not be present when there are no assignees
    assert_select "[data-controller='filter-dropdown'][data-qualifier-type='assignee']", count: 0
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

  test "should handle explicit search_mode parameter" do
    @repository.issues.create!(
      number: 1,
      title: "Test Issue",
      state: "open",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    get repository_issues_url(@repository), params: { search_mode: "github" }
    assert_response :success
  end

  test "should refresh with query parameter preserved" do
    @repository.issues.create!(
      number: 1,
      title: "Test Issue",
      state: "open",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    post refresh_repository_issues_url(@repository), params: { q: "is:open bug" }
    assert_redirected_to repository_issues_url(@repository, q: "is:open bug")
  end

  test "should preserve debug parameter in refresh" do
    issue = @repository.issues.create!(
      number: 1,
      title: "Test Issue",
      state: "open",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    post refresh_repository_issue_url(@repository, issue.number), params: { debug: "true" }
    assert_redirected_to repository_issue_url(@repository, issue.number, debug: "true")
  end

  test "should show rate limit info when debug mode enabled" do
    issue = @repository.issues.create!(
      number: 1,
      title: "Test Issue",
      state: "open",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago,
      cached_at: 1.hour.ago
    )

    mock_service = mock("IssueSyncService")
    mock_service.expects(:call).returns({
      success: true,
      rate_limit: {
        core: { remaining: 4500, limit: 5000, resets_at: 1.hour.from_now }
      }
    })

    Github::IssueSyncService.expects(:new).returns(mock_service)

    get repository_issue_url(@repository, issue.number), params: { debug: "true" }
    assert_response :success
    # Should display rate limit in flash when debug is on
    assert flash[:notice] || flash[:warning]
  end

  test "should refresh individual issue and preserve debug param" do
    issue = @repository.issues.create!(
      number: 42,
      title: "Test Issue",
      state: "open",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago,
      cached_at: 1.hour.ago
    )

    mock_service = mock("IssueSyncService")
    mock_service.expects(:call).returns({ success: true, rate_limit: nil })

    Github::IssueSyncService.expects(:new).with(user: @user, repository: @repository, issue_number: 42).returns(mock_service)

    post refresh_repository_issue_url(@repository, issue.number), params: { debug: "true", q: "test" }
    assert_redirected_to repository_issue_url(@repository, issue.number, debug: "true", q: "test")
  end

  test "should show approaching rate limit warning" do
    @repository.issues.create!(
      number: 1,
      title: "Test Issue",
      state: "open",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    mock_service = mock("IssueSearchService")
    mock_service.expects(:call).returns({
      success: true,
      issues: @repository.issues.to_a,
      mode: :github,
      rate_limit: {
        search: { remaining: 5, limit: 30, resets_at: 1.hour.from_now }
      }
    })

    Github::IssueSearchService.expects(:new).returns(mock_service)

    get repository_issues_url(@repository)
    assert_response :success
    # Should show warning when approaching rate limit (5/30 = 16.7% < 20%)
    assert flash[:warning]
  end

  test "should show rate limit info unavailable in debug mode when no rate limit" do
    @repository.issues.create!(
      number: 1,
      title: "Test Issue",
      state: "open",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    mock_service = mock("IssueSearchService")
    mock_service.expects(:call).returns({
      success: true,
      issues: @repository.issues.to_a,
      mode: :local,
      rate_limit: nil
    })

    Github::IssueSearchService.expects(:new).returns(mock_service)

    get repository_issues_url(@repository), params: { debug: "true" }
    assert_response :success
    assert_equal "Rate limit info unavailable", flash[:notice]
  end

  test "should fall back to local cache on GitHub API failure with rate limit" do
    @repository.issues.create!(
      number: 1,
      title: "Test Issue",
      state: "open",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    # First call fails with rate limit error
    mock_github_service = mock("GitHubIssueSearchService")
    mock_github_service.expects(:call).returns({
      success: false,
      error: "Search rate limit exceeded. Resets at 5:00 PM",
      rate_limit: {
        search: { remaining: 0, limit: 30, resets_at: 1.hour.from_now }
      }
    })

    # Second call succeeds with local data
    mock_local_service = mock("LocalIssueSearchService")
    mock_local_service.expects(:call).returns({
      success: true,
      issues: @repository.issues.to_a,
      mode: :local
    })

    Github::IssueSearchService.expects(:new).twice.returns(mock_github_service, mock_local_service)

    get repository_issues_url(@repository)
    assert_response :success
    assert flash[:alert].include?("rate limit")
    assert flash[:alert].include?("Showing all cached issues")
  end

  test "should fall back to local cache on connection error" do
    @repository.issues.create!(
      number: 1,
      title: "Test Issue",
      state: "open",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    # First call fails with connection error
    mock_github_service = mock("GitHubIssueSearchService")
    mock_github_service.expects(:call).returns({
      success: false,
      error: "Connection timeout"
    })

    # Second call succeeds with local data
    mock_local_service = mock("LocalIssueSearchService")
    mock_local_service.expects(:call).returns({
      success: true,
      issues: @repository.issues.to_a,
      mode: :local
    })

    Github::IssueSearchService.expects(:new).twice.returns(mock_github_service, mock_local_service)

    get repository_issues_url(@repository)
    assert_response :success
    assert flash[:alert].include?("Cannot reach")
    assert flash[:alert].include?("Connection timeout")
  end

  test "should show error when both GitHub and local search fail" do
    # First call fails
    mock_github_service = mock("GitHubIssueSearchService")
    mock_github_service.expects(:call).returns({
      success: false,
      error: "API error"
    })

    # Second call also fails
    mock_local_service = mock("LocalIssueSearchService")
    mock_local_service.expects(:call).returns({
      success: false,
      error: "Local search failed"
    })

    Github::IssueSearchService.expects(:new).twice.returns(mock_github_service, mock_local_service)

    get repository_issues_url(@repository)
    assert_response :success
    # Should show alert for local search failure
    assert flash[:alert]
  end

  test "should handle empty results from local fallback" do
    # First call fails
    mock_github_service = mock("GitHubIssueSearchService")
    mock_github_service.expects(:call).returns({
      success: false,
      error: "API error"
    })

    # Second call succeeds but with no results
    mock_local_service = mock("LocalIssueSearchService")
    mock_local_service.expects(:call).returns({
      success: true,
      issues: [],
      mode: :local
    })

    Github::IssueSearchService.expects(:new).twice.returns(mock_github_service, mock_local_service)

    get repository_issues_url(@repository)
    assert_response :success
    assert flash[:alert].include?("API error")
  end

  test "should handle show action with stale cached issue" do
    issue = @repository.issues.create!(
      number: 1,
      title: "Stale Issue",
      state: "open",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago,
      cached_at: 2.hours.ago
    )

    get repository_issue_url(@repository, issue.number)
    assert_response :success
  end

  test "should handle show action with fresh issue and no cached_at" do
    issue = @repository.issues.create!(
      number: 1,
      title: "Fresh Issue",
      state: "open",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    get repository_issue_url(@repository, issue.number)
    assert_response :success
  end

  test "should handle index with multiple state types" do
    @repository.issues.create!(
      number: 1,
      title: "Open Issue 1",
      state: "open",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )
    @repository.issues.create!(
      number: 2,
      title: "Open Issue 2",
      state: "open",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )
    @repository.issues.create!(
      number: 3,
      title: "Closed Issue",
      state: "closed",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    get repository_issues_url(@repository)
    assert_response :success
    # Should display all issues
    assert_select ".issue-card", count: 3
  end

  test "should extract authors from issues" do
    @repository.issues.create!(
      number: 1,
      title: "Issue by Alice",
      state: "open",
      author_login: "alice",
      author_avatar_url: "https://example.com/alice.png",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )
    @repository.issues.create!(
      number: 2,
      title: "Issue by Bob",
      state: "open",
      author_login: "bob",
      author_avatar_url: "https://example.com/bob.png",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    get repository_issues_url(@repository)
    assert_response :success
    # Authors should be present in response
    assert_match /alice|bob/i, response.body
  end

  test "should handle blank query string in parse" do
    get repository_issues_url(@repository), params: { q: "" }
    assert_response :success
  end

  test "should parse author qualifier" do
    @repository.issues.create!(
      number: 1,
      title: "Issue",
      state: "open",
      author_login: "alice",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    get repository_issues_url(@repository), params: { q: "author:alice" }
    assert_response :success
  end

  test "should show rate limit in debug mode with rate limit data" do
    @repository.issues.create!(
      number: 1,
      title: "Test Issue",
      state: "open",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    mock_service = mock("IssueSearchService")
    mock_service.expects(:call).returns({
      success: true,
      issues: @repository.issues.to_a,
      mode: :github,
      rate_limit: {
        core: { remaining: 4500, limit: 5000, resets_at: 1.hour.from_now }
      }
    })

    Github::IssueSearchService.expects(:new).returns(mock_service)

    get repository_issues_url(@repository), params: { debug: "true" }
    assert_response :success
    assert flash[:notice]
  end

  test "should handle rate limit without approaching threshold" do
    @repository.issues.create!(
      number: 1,
      title: "Test Issue",
      state: "open",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    mock_service = mock("IssueSearchService")
    mock_service.expects(:call).returns({
      success: true,
      issues: @repository.issues.to_a,
      mode: :github,
      rate_limit: {
        core: { remaining: 4500, limit: 5000, resets_at: 1.hour.from_now }
      }
    })

    Github::IssueSearchService.expects(:new).returns(mock_service)

    get repository_issues_url(@repository)
    assert_response :success
    # Should NOT show warning when not approaching limit (4500/5000 = 90%)
    assert_nil flash[:warning]
  end

  test "should handle show with fresh cached issue in debug mode" do
    issue = @repository.issues.create!(
      number: 1,
      title: "Test Issue",
      state: "open",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago,
      cached_at: 5.minutes.ago
    )

    get repository_issue_url(@repository, issue.number), params: { debug: "true" }
    assert_response :success
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  def sign_out
    delete session_url
  end
end
