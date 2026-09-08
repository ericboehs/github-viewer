# frozen_string_literal: true

require "test_helper"

# Covers the GitHub-shaped URL space itself rather than any one page: what the
# router accepts, how a repository is resolved from the path, and the redirects
# that keep one URL per page.
#
# The point of these URLs is that a GitHub link works here with only the scheme
# and host removed, so most of these tests are that claim spelled out.
class GithubUrlsTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "urls@example.com", password: "password123")
    @user.github_tokens.create!(domain: "github.com", token: "ghp_testtesttesttesttest")
    @user.github_tokens.create!(domain: "va.ghe.com", token: "ghp_ghetesttesttesttest")
    sign_in_as(@user)
  end

  def create_repo(domain, owner, name, **attributes)
    @user.repositories.create!(
      github_domain: domain, owner: owner, name: name, full_name: "#{owner}/#{name}",
      cached_at: Time.current, **attributes
    )
  end

  def stub_contents(result = { type: :directory, entries: [] })
    Github::ApiClient.any_instance.stubs(:fetch_contents).returns(result)
  end

  # Routing

  test "routes a github.com repository without naming the host" do
    assert_routing "/rails/rails/issues/5",
      controller: "issues", action: "show", owner: "rails", repo: "rails", number: "5", format: "html"
  end

  test "routes an enterprise repository by naming its host" do
    assert_routing "/va.ghe.com/software/eert/pull/1",
      controller: "pulls", action: "show", github_domain: "va.ghe.com",
      owner: "software", repo: "eert", number: "1", format: "html"
  end

  # Dots are ordinary in repository names and refs but are the only thing that
  # marks out a host, so the two have to stay distinguishable.
  test "reads a dotted repository name as a repository rather than a host" do
    assert_routing "/rails/docs.rs/issues",
      controller: "issues", action: "index", owner: "rails", repo: "docs.rs", format: "html"
  end

  test "keeps a file extension out of the response format" do
    assert_recognizes({
      controller: "trees", action: "show", owner: "rails", repo: "rails",
      ref: "v8.1.0", path: "README.md", format: "html"
    }, "/rails/rails/blob/v8.1.0/README.md")
  end

  # An application route and a repository can want the same first segment. The
  # application wins, which is why GitHub reserves these names too.
  test "prefers an application route to a repository of the same name" do
    assert_routing "/repositories/new", controller: "repositories", action: "new"
  end

  # Resolving the repository

  test "serves a tracked repository named by a bare owner and name" do
    create_repo("github.com", "rails", "rails")
    stub_contents

    get "/rails/rails"

    assert_response :success
  end

  # github.com is implied, so spelling it out is a second URL for one page.
  test "redirects away a redundant github.com host" do
    repository = create_repo("github.com", "rails", "rails")

    get "/github.com/rails/rails/issues/5"

    assert_response :moved_permanently
    assert_redirected_to repo_issue_path(repository, 5)
  end

  test "keeps the query string when dropping a redundant host" do
    create_repo("github.com", "rails", "rails")

    get "/github.com/rails/rails/issues?q=is%3Aopen"

    assert_redirected_to "/rails/rails/issues?q=is%3Aopen"
  end

  # GitHub treats owner and repository names case-insensitively and links in
  # the wild are inconsistent about it.
  test "matches a tracked repository regardless of case" do
    create_repo("github.com", "rails", "rails")
    stub_contents

    get "/Rails/Rails"

    assert_response :success
  end

  # The whole point of mirroring GitHub's paths: a link to a repository you
  # have never opened still works.
  test "syncs an untracked repository named by a URL" do
    Github::ApiClient.any_instance.stubs(:fetch_repository).returns(
      owner: "software", name: "eert", full_name: "software/eert",
      description: "Engineering Excellence", url: "https://va.ghe.com/software/eert",
      default_branch: "main", open_issues_count: 0
    )
    stub_contents

    get "/va.ghe.com/software/eert"

    assert_response :success
    assert @user.repositories.exists?(github_domain: "va.ghe.com", owner: "software", name: "eert")
  end

  test "reports a repository that cannot be synced" do
    Github::RepositorySyncService.any_instance.expects(:call)
      .returns({ success: false, error: "Repository not found" })

    get "/rails/nope/issues"

    assert_redirected_to root_path
    assert_match "Repository not found", flash[:alert]
  end

  # Without a token for the host there is no way to look the repository up, and
  # saying so is more use than a bare 404.
  test "reports a host with no configured token" do
    get "/ghe.example.com/acme/widgets/issues"

    assert_redirected_to root_path
    assert_match "ghe.example.com", flash[:alert]
  end

  test "requires authentication" do
    delete session_url

    get "/rails/rails/issues/5"

    assert_redirected_to new_session_path
  end
end
