# frozen_string_literal: true

require "test_helper"

# Tests CommitsController: a ref's history, and a single commit with its diff.
class CommitsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "commits@example.com", password: "password123")
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

  def commit(sha: "abc1234def5678", subject: "Fix the thing")
    {
      sha: sha,
      subject: subject,
      body: "",
      author_name: "Yehuda Katz",
      author_login: "wycats",
      author_avatar_url: "https://avatars.example/wycats.png",
      authored_at: 2.days.ago
    }
  end

  def stub_commits(result)
    Github::ApiClient.any_instance.stubs(:fetch_commits).returns(result)
  end

  def stub_commit(result)
    Github::ApiClient.any_instance.stubs(:fetch_commit).returns(result)
  end

  test "lists a ref's commits" do
    stub_commits [ commit(subject: "Fix the thing") ]

    get repo_commits_path(@repository)

    assert_response :success
    assert_select "p", text: "Fix the thing"
    assert_select "a[href=?]", repo_commit_path(@repository, "abc1234def5678"), text: "abc1234"
  end

  # No ref in the URL is the default branch, which is what GitHub shows too.
  test "defaults to the repository's default branch" do
    Github::ApiClient.any_instance.expects(:fetch_commits)
      .with("rails", "rails", ref: "main", page: 1, per_page: PagedListing::PAGE_SIZE)
      .returns([])

    get repo_commits_path(@repository)

    assert_response :success
  end

  test "reads the ref from the URL" do
    Github::ApiClient.any_instance.expects(:fetch_commits)
      .with("rails", "rails", ref: "v7.0.0", page: 1, per_page: PagedListing::PAGE_SIZE)
      .returns([])

    get repo_commits_path(@repository, ref: "v7.0.0")

    assert_response :success
  end

  # The ref is the last thing in the URL, so unlike a tree path it can hold
  # slashes as they are.
  test "reads a ref containing slashes" do
    Github::ApiClient.any_instance.expects(:fetch_commits)
      .with("rails", "rails", ref: "release/2025-01", page: 1, per_page: PagedListing::PAGE_SIZE)
      .returns([])

    get "/rails/rails/commits/release/2025-01"

    assert_response :success
  end

  test "pages through history" do
    stub_commits Array.new(PagedListing::PAGE_SIZE) { |index| commit(sha: "sha#{index}") }

    get repo_commits_path(@repository, page: 2)

    assert_select "a[href=?]", repo_commits_path(@repository, ref: "main", page: 3), text: "Older"
    assert_select "a[href=?]", repo_commits_path(@repository, ref: "main", page: 1), text: "Newer"
  end

  test "treats a nonsense page as the first" do
    Github::ApiClient.any_instance.expects(:fetch_commits)
      .with("rails", "rails", ref: "main", page: 1, per_page: PagedListing::PAGE_SIZE)
      .returns([])

    get repo_commits_path(@repository, page: "-3")

    assert_response :success
  end

  test "reports an unknown ref and still renders" do
    stub_commits({ error: "Branch or commit not found" })

    get repo_commits_path(@repository, ref: "nope")

    assert_response :success
    assert_match "Branch or commit not found", response.body
  end

  test "shows one commit with its diff" do
    stub_commit commit.merge(files: [
      { filename: "app/models/user.rb", status: "modified", additions: 3, deletions: 1, changes: 4,
        patch: "@@ -1,2 +1,4 @@\n class User\n+  validates :email\n" }
    ])

    get repo_commit_path(@repository, "abc1234def5678")

    assert_response :success
    assert_select "h2", text: "Fix the thing"
    assert_select "a[href=?]", repo_blob_path(@repository, path: "app/models/user.rb", ref: "abc1234def5678")
    assert_select "p", text: /1 changed file/
  end

  test "offers the tree at the commit's revision" do
    stub_commit commit.merge(files: [])

    get repo_commit_path(@repository, "abc1234def5678")

    assert_select "a[href=?]", repo_tree_path(@repository, ref: "abc1234def5678")
    assert_select "p", text: /does not change any files/
  end

  test "reports a missing commit and still renders" do
    stub_commit({ error: "Branch or commit not found" })

    get repo_commit_path(@repository, "deadbeef")

    assert_response :success
    assert_match "Branch or commit not found", response.body
  end

  test "explains a missing token instead of failing" do
    @token.destroy

    get repo_commits_path(@repository)

    assert_response :success
    assert_match "No GitHub token configured", response.body
  end

  test "offers the repository tabs with Commits current" do
    stub_commits []

    get repo_commits_path(@repository)

    assert_select "a[aria-current=page]", text: "Commits"
    assert_select "a[href=?]", repo_branches_path(@repository), text: "Branches"
  end

  test "requires authentication" do
    delete session_path

    get repo_commits_path(@repository)

    assert_redirected_to new_session_path
  end
end
