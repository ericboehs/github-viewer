require "test_helper"

# Tests for RepositoriesHelper
class RepositoriesHelperTest < ActionView::TestCase
  test "parse_repository_url handles full GitHub.com URL" do
    result = parse_repository_url("https://github.com/rails/rails")

    assert_equal "github.com", result[:domain]
    assert_equal "rails", result[:owner]
    assert_equal "rails", result[:name]
  end

  test "parse_repository_url handles GitHub Enterprise URL" do
    result = parse_repository_url("https://github.example.com/myorg/myrepo")

    assert_equal "github.example.com", result[:domain]
    assert_equal "myorg", result[:owner]
    assert_equal "myrepo", result[:name]
  end

  test "parse_repository_url handles owner/repo shorthand" do
    result = parse_repository_url("rails/rails")

    assert_equal "github.com", result[:domain]
    assert_equal "rails", result[:owner]
    assert_equal "rails", result[:name]
  end

  test "parse_repository_url handles domain/owner/repo shorthand" do
    result = parse_repository_url("github.example.com/myorg/myrepo")

    assert_equal "github.example.com", result[:domain]
    assert_equal "myorg", result[:owner]
    assert_equal "myrepo", result[:name]
  end

  test "parse_repository_url removes .git suffix" do
    result = parse_repository_url("https://github.com/rails/rails.git")

    assert_equal "github.com", result[:domain]
    assert_equal "rails", result[:owner]
    assert_equal "rails", result[:name]
  end

  test "parse_repository_url removes trailing slashes" do
    result = parse_repository_url("https://github.com/rails/rails/")

    assert_equal "github.com", result[:domain]
    assert_equal "rails", result[:owner]
    assert_equal "rails", result[:name]
  end

  test "parse_repository_url handles HTTP URLs" do
    result = parse_repository_url("http://github.com/rails/rails")

    assert_equal "github.com", result[:domain]
    assert_equal "rails", result[:owner]
    assert_equal "rails", result[:name]
  end

  test "parse_repository_url returns nil for blank input" do
    assert_nil parse_repository_url("")
    assert_nil parse_repository_url("   ")
    assert_nil parse_repository_url(nil)
  end

  test "parse_repository_url returns nil for invalid format" do
    assert_nil parse_repository_url("invalid")
    assert_nil parse_repository_url("owner/repo/extra/parts")
  end

  test "parse_repository_url returns nil for malformed URL" do
    assert_nil parse_repository_url("https://github.com")
    assert_nil parse_repository_url("https://github.com/")
    assert_nil parse_repository_url("https://github.com/owner")
  end

  test "parse_repository_url strips whitespace" do
    result = parse_repository_url("  rails/rails  ")

    assert_equal "github.com", result[:domain]
    assert_equal "rails", result[:owner]
    assert_equal "rails", result[:name]
  end
end
