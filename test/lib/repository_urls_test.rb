# frozen_string_literal: true

require "test_helper"

# Covers the parts of URL building that are decisions rather than routing:
# when the host is named, and what ref a caller that has none ends up with.
class RepositoryUrlsTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  def repository(domain: "github.com", default_branch: nil)
    Repository.new(github_domain: domain, owner: "rails", name: "rails", default_branch: default_branch)
  end

  test "leaves github.com out of the path" do
    assert_nil RepositoryUrls.segments(repository)[:github_domain]
  end

  test "names any other host" do
    assert_equal "va.ghe.com", RepositoryUrls.segments(repository(domain: "va.ghe.com"))[:github_domain]
  end

  # The repository root is its own URL, so a breadcrumb pointing at the top of
  # the tree does not have to invent a ref to get there.
  test "builds the repository root when given neither a ref nor a path" do
    assert_equal "/rails/rails", repo_tree_path(repository(default_branch: "main"))
  end

  test "falls back to the default branch for a path with no ref" do
    assert_equal "/rails/rails/tree/main/app", repo_tree_path(repository(default_branch: "main"), path: "app")
  end

  # A repository we have never synced has no default branch recorded, and
  # GitHub resolves HEAD the same way it resolves a branch name.
  test "falls back to HEAD for a repository with no known default branch" do
    assert_equal "/rails/rails/tree/HEAD/app", repo_tree_path(repository, path: "app")
  end

  test "links a file under blob and a directory under tree" do
    repo = repository(default_branch: "main")

    assert_equal "/rails/rails/blob/main/README.md", repo_blob_path(repo, path: "README.md")
    assert_equal "/rails/rails/tree/main/app", repo_tree_path(repo, path: "app")
  end

  # blob names a file, so with nothing to name it degrades to the tree it would
  # otherwise sit in rather than generating an unroutable path.
  test "falls back to a tree path when a blob has no path" do
    assert_equal "/rails/rails/tree/v1.0", repo_blob_path(repository, ref: "v1.0")
  end

  test "keeps query parameters" do
    assert_equal "/rails/rails/issues?q=is%3Aopen", repo_issues_path(repository, q: "is:open")
  end

  # A tree URL is ref-then-path, so a ref with a slash in it would read as one
  # segment of ref and the rest as path. Percent-encoding keeps it whole, and
  # Rails unescapes it on the way back in.
  test "escapes the slashes in a ref" do
    repo = repository

    assert_equal "/rails/rails/tree/release%2F2025-01", repo_tree_path(repo, ref: "release/2025-01")
    assert_equal "/rails/rails/blob/release%2F2025-01/README.md",
                repo_blob_path(repo, ref: "release/2025-01", path: "README.md")
  end

  # A commits URL ends with the ref, so there is nothing for the extra segments
  # to be confused with and the slashes can stay as they are.
  test "leaves the slashes in a commits ref alone" do
    assert_equal "/rails/rails/commits/release/2025-01", repo_commits_path(repository, ref: "release/2025-01")
  end

  test "falls back to the default branch for a commits path with no ref" do
    assert_equal "/rails/rails/commits/main", repo_commits_path(repository(default_branch: "main"))
  end
end
