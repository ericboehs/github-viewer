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

  # Commits and Files tabs

  test "should list commits for a pull request" do
    pull = create_pull_request(number: 20, title: "Tabbed", cached_at: Time.current)
    stub_api_client(fetch_pull_request_commits: [ sample_commit ])

    get commits_repository_pull_url(@repository, pull.number)

    assert_response :success
    assert_select "h1", /Tabbed/
    assert_match "Add a thing", response.body
    assert_match "abc1234", response.body
  end

  test "should show an empty state when a pull request has no commits" do
    pull = create_pull_request(number: 21, title: "Empty", cached_at: Time.current)
    stub_api_client(fetch_pull_request_commits: [])

    get commits_repository_pull_url(@repository, pull.number)

    assert_response :success
    assert_match I18n.t("pulls.commits.empty"), response.body
  end

  test "should list changed files with their diffs" do
    pull = create_pull_request(number: 22, title: "Diffed", cached_at: Time.current)
    stub_api_client(fetch_pull_request_files: [ sample_file ])

    get files_repository_pull_url(@repository, pull.number)

    assert_response :success
    assert_match "README.md", response.body
    assert_match "a new line", response.body
  end

  # A failed fetch should still render the page around the error, so the tabs
  # and header stay usable.
  test "should render the commits tab with an alert when the API fails" do
    pull = create_pull_request(number: 23, title: "Broken", cached_at: Time.current)
    stub_api_client(fetch_pull_request_commits: { error: "rate limited" })

    get commits_repository_pull_url(@repository, pull.number)

    assert_response :success
    assert_match "rate limited", flash[:alert]
    assert_match I18n.t("pulls.commits.empty"), response.body
  end

  test "should render the files tab with an alert when the API fails" do
    pull = create_pull_request(number: 24, title: "Broken", cached_at: Time.current)
    stub_api_client(fetch_pull_request_files: { error: "boom" })

    get files_repository_pull_url(@repository, pull.number)

    assert_response :success
    assert_match "boom", flash[:alert]
    assert_match I18n.t("pulls.files.empty"), response.body
  end

  test "should report a missing token on the commits tab" do
    pull = create_pull_request(number: 25, title: "No token", cached_at: Time.current)
    @user.github_tokens.destroy_all

    get commits_repository_pull_url(@repository, pull.number)

    assert_response :success
    assert_match "github.com", flash[:alert]
  end

  # The scope guard from the show page has to apply to the tabs too, otherwise
  # /pulls/N/commits would happily render for a plain issue.
  test "should redirect the commits tab to the issue page for a plain issue" do
    issue = @repository.issues.create!(
      number: 26,
      title: "Not a pull request",
      state: "open",
      cached_at: Time.current,
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    get commits_repository_pull_url(@repository, issue.number)

    assert_redirected_to repository_issue_path(@repository, issue.number)
  end

  test "should render the tab bar with cached counts and diffstat" do
    pull = create_pull_request(number: 27, title: "Counted", cached_at: Time.current)
    pull.update!(comments_count: 4, commits_count: 3, changed_files_count: 2, additions: 608, deletions: 12)
    stub_api_client(fetch_pull_request_commits: [])

    get commits_repository_pull_url(@repository, pull.number)

    assert_response :success
    assert_select "nav[aria-label=?]", I18n.t("pulls.tabs.aria_label")
    assert_select "a[href=?]", repository_pull_path(@repository, pull.number)
    assert_select "a[href=?][aria-current=page]", commits_repository_pull_path(@repository, pull.number)
    assert_match "+608", response.body
  end

  private

  def create_pull_request(number:, title:, state: "open", cached_at: nil)
    @repository.issues.create!(
      number: number,
      title: title,
      state: state,
      pull_request: true,
      cached_at: cached_at,
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )
  end

  # The tabs fetch live, so they need a client rather than cached rows.
  def stub_api_client(stubs)
    client = mock("api_client")
    stubs.each { |method, value| client.stubs(method).returns(value) }
    Github::ApiClient.stubs(:new).returns(client)
    client
  end

  def sample_commit
    {
      sha: "abc1234def5678",
      subject: "Add a thing",
      body: "",
      author_name: "Eric",
      author_login: "ericboehs",
      author_avatar_url: "https://example.com/a.png",
      authored_at: 2.days.ago
    }
  end

  def sample_file
    {
      filename: "README.md",
      previous_filename: nil,
      status: "modified",
      additions: 1,
      deletions: 0,
      changes: 1,
      patch: "@@ -1,2 +1,3 @@\n context\n+a new line\n context"
    }
  end

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end
end
