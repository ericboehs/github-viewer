# frozen_string_literal: true

require "test_helper"

# Tests the ProxyController for on-demand issue viewing via proxy-style URLs
class ProxyControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email_address: "test@example.com",
      password: "password123"
    )
    @github_token = @user.github_tokens.create!(
      domain: "github.com",
      token: "ghp_test1234567890abcdef"
    )
    @ghe_token = @user.github_tokens.create!(
      domain: "va.ghe.com",
      token: "ghp_ghe_test1234567890abcdef"
    )
    sign_in_as(@user)
  end

  # Pasting a GitHub file URL against this host should land on the file
  # browser rather than 404.
  test "should redirect a blob URL to the file browser" do
    repo = create_repo("va.ghe.com", "software", "eert")

    get "/va.ghe.com/software/eert/blob/main/projects/vapo/README.md"

    assert_redirected_to repository_tree_path(repo, path: "projects/vapo/README.md", ref: "main")
  end

  test "should redirect a tree URL to the file browser" do
    repo = create_repo("github.com", "rails", "rails")

    get "/rails/rails/tree/main/app/models"

    assert_redirected_to repository_tree_path(repo, path: "app/models", ref: "main")
  end

  # The repository is created on demand for a blob URL exactly as it is for an
  # issue URL, so a link to a repository you have never opened still works.
  test "should sync an unknown repository named by a blob URL" do
    Github::RepositorySyncService.any_instance.stubs(:call).returns(
      { success: true, repository: create_repo("github.com", "rails", "new-repo") }
    )

    get "/rails/new-repo/blob/main/README.md"

    assert_response :redirect
    assert_match(/\/tree/, response.location)
  end

  test "should refuse a blob URL for a domain with no token" do
    @ghe_token.destroy

    get "/va.ghe.com/software/eert/blob/main/README.md"

    assert_redirected_to root_path
    assert_match(/No GitHub token/, flash[:alert])
  end

  # Path parsing tests - two-segment (owner/repo) defaults to github.com
  test "should view issue via owner/repo path defaulting to github.com" do
    repo = create_repo("github.com", "rails", "rails")
    create_issue(repo, 123, "Test Issue")

    get "/rails/rails/issues/123"
    assert_response :success
    assert_select "h1", text: /Test Issue/
  end

  # GitHub's own pull request URLs use /pull/:number
  test "should view pull request via owner/repo/pull path" do
    repo = create_repo("github.com", "rails", "rails")
    pull = create_issue(repo, 456, "Test Pull Request")
    pull.update!(pull_request: true)

    get "/rails/rails/pull/456"
    assert_response :success
    assert_select "h1", text: /Test Pull Request/
    # Refresh button and back links stay in the pulls scope
    assert_select "form[action=?]", refresh_repository_pull_path(repo, 456)
  end

  test "should link a proxied pull request back to GitHub's pull URL" do
    repo = create_repo("github.com", "rails", "rails")
    pull = create_issue(repo, 456, "Test Pull Request")
    pull.update!(pull_request: true)

    get "/rails/rails/pull/456"
    assert_response :success
    assert_select "a[href=?]", "https://github.com/rails/rails/pull/456"
  end

  # Three-segment with dot: domain/owner/repo for GHE
  test "should view issue via domain/owner/repo path for GHE" do
    repo = create_repo("va.ghe.com", "software", "eert")
    create_issue(repo, 185, "GHE Issue")

    get "/va.ghe.com/software/eert/issues/185"
    assert_response :success
    assert_select "h1", text: /GHE Issue/
  end

  # Auto-creates repository when visiting proxy URL for untracked repo
  test "should auto-create repository when not tracked" do
    # No repo exists initially - stub sync service to create it
    Github::RepositorySyncService.any_instance.stubs(:call).returns(
      { success: true, repository: create_repo("github.com", "rails", "rails").tap { |r|
        create_issue(r, 123, "Auto-created Repo Issue")
      } }
    )

    get "/rails/rails/issues/123"
    assert_response :success
    assert_select "h1", text: /Auto-created Repo Issue/
  end

  # Fetches stale issues on-demand
  test "should re-fetch stale issue" do
    repo = create_repo("github.com", "rails", "rails")
    create_issue(repo, 42, "Stale Issue", cached_at: 10.minutes.ago)

    # Stale issue triggers sync
    Github::IssueSyncService.any_instance.stubs(:call).returns({ success: true, synced_count: 1 })

    get "/rails/rails/issues/42"
    assert_response :success
    assert_select "h1", text: /Stale Issue/
  end

  # Error handling
  test "should redirect with error for invalid URL format" do
    get "/just-one-segment/issues/123"
    assert_redirected_to root_path
    assert_match /Invalid GitHub URL/, flash[:alert]
  end

  test "should not match paths without issues segment" do
    get "/rails/rails/pulls/123"
    assert_response :not_found
  end

  test "should redirect when no token for domain" do
    get "/unknown.example.com/org/repo/issues/1"
    assert_redirected_to root_path
    assert_match /No GitHub token configured for unknown.example.com/, flash[:alert]
  end

  test "should redirect when repository not found on GitHub" do
    Github::RepositorySyncService.any_instance.stubs(:call).returns({ success: false, error: "Not Found" })

    get "/nonexistent/repo/issues/1"
    assert_redirected_to root_path
    assert_match /Could not find repository/, flash[:alert]
  end

  test "should redirect to root when issue sync fails and issue not cached" do
    create_repo("github.com", "rails", "rails")
    Github::IssueSyncService.any_instance.stubs(:call).returns({ success: false, error: "Issue not found", cache_preserved: true })

    get "/rails/rails/issues/99999"
    assert_redirected_to root_path
    assert_match /Issue not found/, flash[:alert]
  end

  test "should display stale cached issue when sync fails" do
    repo = create_repo("github.com", "rails", "rails")
    create_issue(repo, 42, "Stale But Visible", cached_at: 10.minutes.ago)

    Github::IssueSyncService.any_instance.stubs(:call).returns({ success: false, error: "API rate limited" })

    get "/rails/rails/issues/42"
    assert_response :success
    assert_select "h1", text: /Stale But Visible/
  end

  # Authentication
  test "should require authentication" do
    sign_out
    get "/rails/rails/issues/123"
    assert_redirected_to new_session_url
  end

  test "should not match non-numeric issue numbers" do
    get "/rails/rails/issues/abc"
    assert_response :not_found
  end

  test "should reject three-segment path without dot in first segment" do
    get "/org/sub/repo/issues/1"
    assert_redirected_to root_path
    assert_match /Invalid GitHub URL/, flash[:alert]
  end

  # Path parsing rejections

  test "should redirect on paths that are too short" do
    get "/rails/issues/1"
    assert_redirected_to root_path
    assert_match(/Invalid GitHub URL format/, flash[:alert])
  end

  test "should redirect on zero issue numbers" do
    get "/rails/rails/issues/0"
    assert_redirected_to root_path
    assert_match(/Invalid GitHub URL format/, flash[:alert])
  end

  test "should redirect on paths with too many segments" do
    get "/a/b/c/d/issues/1"
    assert_redirected_to root_path
    assert_match(/Invalid GitHub URL format/, flash[:alert])
  end

  test "should redirect when the repository cannot be found on GitHub" do
    Github::RepositorySyncService.any_instance.stubs(:call).returns(
      { success: false, error: "Not Found" }
    )

    get "/unknown/repo/issues/1"

    assert_redirected_to root_path
    assert_match(/Could not find repository unknown\/repo on github.com/, flash[:alert])
  end

  private

  def create_repo(domain, owner, name)
    @user.repositories.create!(
      github_domain: domain,
      owner: owner,
      name: name,
      full_name: "#{owner}/#{name}",
      url: "https://#{domain}/#{owner}/#{name}",
      cached_at: Time.current
    )
  end

  def create_issue(repo, number, title, cached_at: 1.minute.ago)
    repo.issues.create!(
      number: number,
      title: title,
      state: "open",
      body: "Test body",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago,
      cached_at: cached_at
    )
  end

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  def sign_out
    delete session_url
  end
end
