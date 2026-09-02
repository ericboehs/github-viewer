# frozen_string_literal: true

require "test_helper"

# Tests TreesController, the repository file browser. One GitHub endpoint
# serves both directories and files, so the tests cover the fork between them
# as well as the failure paths.
class TreesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "tree@example.com", password: "password123")
    @token = @user.github_tokens.create!(domain: "github.com", token: "ghp_testtesttesttesttest")
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

  def stub_contents(result)
    Github::ApiClient.any_instance.stubs(:fetch_contents).returns(result)
  end

  def directory(entries)
    { type: :directory, entries: entries }
  end

  test "lists a directory" do
    stub_contents directory([
      { name: "app", path: "app", type: "dir", size: 0 },
      { name: "README.md", path: "README.md", type: "file", size: 2048 }
    ])

    get repository_tree_path(@repository)

    assert_response :success
    assert_select "a", text: "app"
    assert_select "a", text: "README.md"
    assert_select "td", text: /2 KB/
  end

  test "renders a file's contents" do
    stub_contents({ type: :file, path: "config/routes.rb", size: 12, binary: false, content: "Rails.routes\n" })

    get repository_tree_path(@repository, path: "config/routes.rb")

    assert_response :success
    assert_select "code.language-ruby"
    assert_select "nav[aria-label=?] span", "File path", text: "routes.rb"
  end

  # The browser and the API both cope badly with stray slashes.
  test "strips leading and trailing slashes from the path" do
    Github::ApiClient.any_instance.expects(:fetch_contents)
      .with("rails", "rails", "app/models", ref: nil)
      .returns(directory([]))

    get repository_tree_path(@repository, path: "/app/models/")

    assert_response :success
  end

  test "passes a ref through to the API" do
    Github::ApiClient.any_instance.expects(:fetch_contents)
      .with("rails", "rails", "", ref: "v7.0.0")
      .returns(directory([]))

    get repository_tree_path(@repository, ref: "v7.0.0")

    assert_response :success
    assert_select "p", text: /v7\.0\.0/
  end

  test "shows an empty directory rather than a blank page" do
    stub_contents directory([])

    get repository_tree_path(@repository, path: "app")

    assert_response :success
    assert_select "p", text: /empty/i
  end

  # A bad path must not 500; the breadcrumb stays usable so you can climb out.
  test "reports a missing path and still renders" do
    stub_contents({ error: "File not found" })

    get repository_tree_path(@repository, path: "nope.rb")

    assert_response :success
    assert_select "nav[aria-label=?]", "File path"
    assert_match "File not found", response.body
  end

  test "explains a missing token instead of failing" do
    @token.destroy

    get repository_tree_path(@repository)

    assert_response :success
    assert_match "No GitHub token configured", response.body
  end

  test "does not expose another user's repository" do
    other = User.create!(email_address: "other@example.com", password: "password123")
    theirs = other.repositories.create!(
      github_domain: "github.com", owner: "x", name: "y", full_name: "x/y"
    )

    get repository_tree_path(theirs)

    assert_response :not_found
  end

  # Reachable without hand-typing a URL, and reachable back out again.
  test "offers the repository tabs with Code current" do
    stub_contents directory([])

    get repository_tree_path(@repository)

    assert_select "a[aria-current=page]", text: "Code"
    assert_select "a[href=?]", repository_issues_path(@repository), text: "Issues"
    assert_select "a[href=?]", repository_pulls_path(@repository), text: "Pull requests"
  end

  test "requires authentication" do
    delete session_path

    get repository_tree_path(@repository)

    assert_redirected_to new_session_path
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end
end
