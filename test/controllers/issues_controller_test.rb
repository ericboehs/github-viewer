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
