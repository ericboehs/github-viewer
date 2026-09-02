# frozen_string_literal: true

require "test_helper"

# Tests ProxyPath, which turns a pasted GitHub-shaped URL into the repository
# and target it names.
class ProxyPathTest < ActiveSupport::TestCase
  test "parses an issue on the implied github.com" do
    assert_equal(
      { domain: "github.com", owner: "rails", name: "rails",
        kind: :issue, issue_number: 123, scope: IssueScoped::ISSUES_SCOPE },
      ProxyPath.parse("rails/rails/issues/123")
    )
  end

  test "parses an issue on a named host" do
    parsed = ProxyPath.parse("va.ghe.com/software/eert/issues/185")

    assert_equal "va.ghe.com", parsed[:domain]
    assert_equal "software", parsed[:owner]
    assert_equal "eert", parsed[:name]
    assert_equal 185, parsed[:issue_number]
  end

  test "maps a pull path to the pulls scope" do
    parsed = ProxyPath.parse("rails/rails/pull/9")

    assert_equal IssueScoped::PULLS_SCOPE, parsed[:scope]
    assert_equal 9, parsed[:issue_number]
  end

  test "parses a blob URL into a ref and a path" do
    assert_equal(
      { domain: "va.ghe.com", owner: "software", name: "eert",
        kind: :tree, ref: "main", path: "projects/vapo/README.md" },
      ProxyPath.parse("va.ghe.com/software/eert/blob/main/projects/vapo/README.md")
    )
  end

  # blob and tree differ only in what they point at, which our file browser
  # works out for itself.
  test "parses a tree URL the same way" do
    parsed = ProxyPath.parse("rails/rails/tree/main/app/models")

    assert_equal :tree, parsed[:kind]
    assert_equal "main", parsed[:ref]
    assert_equal "app/models", parsed[:path]
    assert_equal "github.com", parsed[:domain]
  end

  # A repository root at a ref, with nothing after it.
  test "parses a tree URL with no path" do
    parsed = ProxyPath.parse("rails/rails/tree/main")

    assert_equal "main", parsed[:ref]
    assert_equal "", parsed[:path]
  end

  test "parses a blob URL at a commit sha" do
    parsed = ProxyPath.parse("rails/rails/blob/8f3c2a1/Gemfile")

    assert_equal "8f3c2a1", parsed[:ref]
    assert_equal "Gemfile", parsed[:path]
  end

  # The ref is taken as one segment, so a slash in a branch name is read as
  # part of the path. Documented rather than fixed: telling them apart needs
  # GitHub to say which refs exist.
  test "takes only the first segment as the ref" do
    parsed = ProxyPath.parse("rails/rails/blob/release/2025-01/Gemfile")

    assert_equal "release", parsed[:ref]
    assert_equal "2025-01/Gemfile", parsed[:path]
  end

  # A host-prefixed URL is checked first, so a repository named "blob" is not
  # mistaken for the marker.
  test "prefers the host form when a repository is named blob" do
    parsed = ProxyPath.parse("va.ghe.com/software/blob/tree/main/README.md")

    assert_equal "va.ghe.com", parsed[:domain]
    assert_equal "software", parsed[:owner]
    assert_equal "blob", parsed[:name]
    assert_equal "main", parsed[:ref]
  end

  test "rejects a blob URL with no ref" do
    assert_nil ProxyPath.parse("rails/rails/blob")
  end

  test "rejects unsupported kinds" do
    assert_nil ProxyPath.parse("rails/rails/discussions/1")
  end

  test "rejects a blank path" do
    assert_nil ProxyPath.parse("")
    assert_nil ProxyPath.parse(nil)
  end

  test "rejects a non-numeric issue number" do
    assert_nil ProxyPath.parse("rails/rails/issues/abc")
    assert_nil ProxyPath.parse("rails/rails/issues/0")
  end

  test "rejects too many segments before the kind" do
    assert_nil ProxyPath.parse("a/b/c/d/issues/1")
  end

  # Three segments only mean a host if the first looks like one.
  test "rejects a three segment prefix that is not a host" do
    assert_nil ProxyPath.parse("a/b/c/issues/1")
  end
end
