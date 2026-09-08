# frozen_string_literal: true

require "test_helper"

# Tests BranchesController, which lists a repository's branches straight from
# the API.
class BranchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "branches@example.com", password: "password123")
    @token = @user.github_tokens.create!(domain: "github.com", token: "ghp_testtesttesttesttest")
    @repository = @user.repositories.create!(
      github_domain: "github.com",
      owner: "rails",
      name: "rails",
      full_name: "rails/rails",
      url: "https://github.com/rails/rails",
      default_branch: "main",
      cached_at: 1.hour.ago
    )
    sign_in_as(@user)
  end

  def branch(name, sha: "abc1234def5678", protected_branch: false)
    { name: name, sha: sha, protected: protected_branch }
  end

  def stub_branches(result)
    Github::ApiClient.any_instance.stubs(:fetch_branches).returns(result)
  end

  test "lists branches with links to their trees and histories" do
    stub_branches [ branch("main"), branch("spike") ]

    get repo_branches_path(@repository)

    assert_response :success
    assert_select "a[href=?]", repo_tree_path(@repository, ref: "main"), text: "main"
    assert_select "a[href=?]", repo_commits_path(@repository, ref: "spike"), text: "Commits"
    assert_select "a[href=?]", repo_commit_path(@repository, "abc1234def5678"), text: "abc1234"
  end

  test "marks the default and protected branches" do
    stub_branches [ branch("main", protected_branch: true), branch("spike") ]

    get repo_branches_path(@repository)

    assert_select "span", text: "Default"
    assert_select "span", text: "Protected"
  end

  # A slash is ordinary in a branch name, and would otherwise read as two path
  # segments; see RepositoryUrls.
  test "links a branch whose name contains slashes" do
    stub_branches [ branch("dependabot/bundler/rails-8.1.0") ]

    get repo_branches_path(@repository)

    assert_response :success
    assert_select "a[href=?]", "/rails/rails/tree/dependabot%2Fbundler%2Frails-8.1.0"
  end

  test "offers a next page only while pages come back full" do
    stub_branches Array.new(PagedListing::PAGE_SIZE) { |index| branch("branch-#{index}") }

    get repo_branches_path(@repository)

    assert_select "a[href=?]", repo_branches_path(@repository, page: 2), text: "Older"
    assert_select "a", text: "Newer", count: 0
  end

  test "offers a previous page from page two" do
    stub_branches [ branch("main") ]

    get repo_branches_path(@repository, page: 2)

    assert_select "a[href=?]", repo_branches_path(@repository, page: 1), text: "Newer"
    assert_select "a", text: "Older", count: 0
  end

  test "shows an empty state rather than a blank page" do
    stub_branches []

    get repo_branches_path(@repository)

    assert_response :success
    assert_select "p", text: /no branches/i
  end

  test "reports an API failure and still renders" do
    stub_branches({ error: "Repository not found" })

    get repo_branches_path(@repository)

    assert_response :success
    assert_match "Repository not found", response.body
  end

  test "explains a missing token instead of failing" do
    @token.destroy

    get repo_branches_path(@repository)

    assert_response :success
    assert_match "No GitHub token configured", response.body
  end

  test "requires authentication" do
    delete session_path

    get repo_branches_path(@repository)

    assert_redirected_to new_session_path
  end
end
