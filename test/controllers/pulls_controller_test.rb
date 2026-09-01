# frozen_string_literal: true

require "test_helper"

# Tests the PullsController, which reuses the issue list/show machinery with
# the list scope forced to pull requests
class PullsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email_address: "pulls@example.com",
      password: "password123"
    )
    @user.github_tokens.create!(
      domain: "github.com",
      token: "ghp_testtesttesttesttest"
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

  # Index

  test "should get index" do
    create_pull_request(number: 1, title: "Add caching layer")

    get repository_pulls_url(@repository)

    assert_response :success
    assert_select "h1", text: "rails/rails"
    assert_select ".issue-card", count: 1
  end

  test "should default to the is:pr state:open query" do
    get repository_pulls_url(@repository)

    assert_response :success
    assert_select "input[name=?][value=?]", "q", "is:pr state:open "
  end

  test "should only list pull requests, never issues" do
    create_pull_request(number: 1, title: "A pull request")
    @repository.issues.create!(
      number: 2,
      title: "A plain issue",
      state: "open",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    get repository_pulls_url(@repository)

    assert_response :success
    assert_select ".issue-card", count: 1
    assert_select "a", text: "A pull request"
    assert_select "a", text: "A plain issue", count: 0
  end

  test "should force the pr type even when the query says is:issue" do
    create_pull_request(number: 1, title: "A pull request")
    @repository.issues.create!(
      number: 2,
      title: "A plain issue",
      state: "open",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    get repository_pulls_url(@repository, q: "is:issue state:open")

    assert_response :success
    assert_select "a", text: "A pull request"
    assert_select "a", text: "A plain issue", count: 0
  end

  test "should link cards to the pulls detail route" do
    create_pull_request(number: 7, title: "Linked pull request")

    get repository_pulls_url(@repository)

    assert_response :success
    assert_select "a[href=?]", repository_pull_path(@repository, 7)
  end

  test "should render issues and pull requests tabs" do
    create_pull_request(number: 1, title: "A pull request")

    get repository_pulls_url(@repository)

    assert_response :success
    assert_select "a[href=?]", repository_issues_path(@repository), text: "Issues"
    assert_select "a[href=?][aria-current=?]", repository_pulls_path(@repository), "page", text: "Pull requests"
  end

  test "should show empty state when no pull requests exist" do
    @repository.issues.create!(
      number: 1,
      title: "A plain issue",
      state: "open",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    get repository_pulls_url(@repository)

    assert_response :success
    assert_select "h3", text: "No pull requests found"
  end

  # Show

  test "should show an individual pull request" do
    pull = create_pull_request(number: 42, title: "Fix critical bug")
    pull.update!(cached_at: Time.current)

    get repository_pull_url(@repository, pull.number)

    assert_response :success
    assert_select "h1", text: /Fix critical bug/
  end

  test "should link a pull request back to GitHub's pull URL" do
    pull = create_pull_request(number: 42, title: "Fix critical bug")
    pull.update!(cached_at: Time.current)

    get repository_pull_url(@repository, pull.number)

    assert_response :success
    assert_select "a[href=?]", "https://github.com/rails/rails/pull/42"
  end

  test "should redirect to the pulls index when a pull request is not found" do
    Github::IssueSyncService.any_instance.stubs(:call).returns(
      { success: false, error: "Issue not found", cache_preserved: true }
    )

    get repository_pull_url(@repository, 999)

    assert_redirected_to repository_pulls_path(@repository)
  end

  test "should display merged state for a merged pull request" do
    pull = create_pull_request(number: 8, title: "Merged work", state: "closed")
    pull.update!(merged_at: 1.hour.ago, cached_at: Time.current)

    get repository_pull_url(@repository, pull.number)

    assert_response :success
    assert_select "span", text: /Merged/
  end

  # GitHub 302s between the two URL spaces; without this a pulls URL renders a
  # plain issue on a page whose refresh button posts to the pulls route.
  test "should redirect to the issue page when the number is not a pull request" do
    issue = @repository.issues.create!(
      number: 41,
      title: "Plain issue",
      state: "open",
      pull_request: false,
      cached_at: Time.current
    )

    get repository_pull_url(@repository, issue.number)

    assert_redirected_to repository_issue_path(@repository, issue.number)
  end

  # Refresh

  test "should refresh all pull requests and redirect to the pulls index" do
    Github::IssueSyncService.any_instance.stubs(:call).returns({ success: true, synced_count: 3 })

    post refresh_repository_pulls_url(@repository)

    assert_redirected_to repository_pulls_path(@repository)
  end

  test "should refresh a single pull request and redirect to its page" do
    pull = create_pull_request(number: 12, title: "Refresh me")
    Github::IssueSyncService.any_instance.stubs(:call).returns({ success: true, synced_count: 1 })

    post refresh_repository_pull_url(@repository, pull.number)

    assert_redirected_to repository_pull_path(@repository, pull.number)
  end

  test "should report refresh failures" do
    Github::IssueSyncService.any_instance.stubs(:call).returns({ success: false, error: "boom" })

    post refresh_repository_pulls_url(@repository)

    assert_redirected_to repository_pulls_path(@repository)
    assert_match "boom", flash[:alert]
  end

  private

  def create_pull_request(number:, title:, state: "open")
    @repository.issues.create!(
      number: number,
      title: title,
      state: state,
      pull_request: true,
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )
  end

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end
end
