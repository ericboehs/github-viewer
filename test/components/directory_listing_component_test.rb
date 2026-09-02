# frozen_string_literal: true

require "test_helper"

# Tests DirectoryListingComponent and TreeBreadcrumbComponent, the two pieces
# of the repository file browser's chrome.
class DirectoryListingComponentTest < ViewComponent::TestCase
  include Rails.application.routes.url_helpers

  setup do
    @repository = Repository.new(
      id: 1, github_domain: "github.com", owner: "rails", name: "rails", full_name: "rails/rails"
    )
  end

  def entry(name:, type: "file", size: 100, path: nil)
    { name: name, path: path || name, type: type, size: size }
  end

  test "links directories and files" do
    render_inline(DirectoryListingComponent.new(
      entries: [ entry(name: "app", type: "dir", size: 0), entry(name: "README.md", size: 2048) ],
      repository: @repository
    ))

    assert_selector "a", text: "app"
    assert_selector "a", text: "README.md"
  end

  # A directory's size is reported as 0 and means nothing, so showing it would
  # be actively misleading.
  test "shows a size for files only" do
    component = DirectoryListingComponent.new(entries: [], repository: @repository)

    assert_equal 2048, component.size_for(entry(name: "a.rb", size: 2048))
    assert_nil component.size_for(entry(name: "app", type: "dir", size: 0))
  end

  # A submodule or symlink has nothing to browse into.
  test "does not link an entry that cannot be opened" do
    render_inline(DirectoryListingComponent.new(
      entries: [ entry(name: "vendored", type: "submodule", size: 0) ],
      repository: @repository
    ))

    assert_no_selector "a", text: "vendored"
    assert_text "vendored"
  end

  test "offers a parent link below the root only" do
    at_root = DirectoryListingComponent.new(entries: [], repository: @repository, path: "")
    nested = DirectoryListingComponent.new(entries: [], repository: @repository, path: "app/models")
    shallow = DirectoryListingComponent.new(entries: [], repository: @repository, path: "app")

    assert_nil at_root.parent_path
    assert_equal "app", nested.parent_path
    assert_equal "", shallow.parent_path
  end

  test "renders an empty directory message" do
    render_inline(DirectoryListingComponent.new(entries: [], repository: @repository))

    assert_text "This directory is empty"
  end
end

# Tests the owner/dir/dir trail above a listing.
class TreeBreadcrumbComponentTest < ViewComponent::TestCase
  include Rails.application.routes.url_helpers

  setup do
    @repository = Repository.new(
      id: 1, github_domain: "github.com", owner: "rails", name: "rails", full_name: "rails/rails"
    )
  end

  test "pairs each segment with the path that reaches it" do
    component = TreeBreadcrumbComponent.new(repository: @repository, path: "app/models/issue.rb")

    assert_equal [
      [ "app", "app" ],
      [ "models", "app/models" ],
      [ "issue.rb", "app/models/issue.rb" ]
    ], component.crumbs
  end

  test "has no crumbs at the root" do
    assert_empty TreeBreadcrumbComponent.new(repository: @repository, path: "").crumbs
  end

  # The page you are on is not somewhere to navigate to.
  test "renders the last segment as text, earlier ones as links" do
    render_inline(TreeBreadcrumbComponent.new(repository: @repository, path: "app/models"))

    assert_selector "a", text: "app"
    assert_no_selector "a", text: "models"
    assert_selector "span[aria-current=page]", text: "models"
  end
end
