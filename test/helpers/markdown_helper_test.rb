# frozen_string_literal: true

require "test_helper"

class MarkdownHelperTest < ActionView::TestCase
  test "renders markdown to HTML" do
    markdown = "# Heading\n\nThis is **bold** text"
    result = render_markdown(markdown)

    assert_match(/<h1/, result)
    assert_match(/Heading/, result)
    assert_match(/<strong/, result)
    assert_match(/bold/, result)
  end

  test "returns empty string for nil text" do
    assert_equal "", render_markdown(nil)
  end

  test "returns empty string for blank text" do
    assert_equal "", render_markdown("")
    assert_equal "", render_markdown("   ")
  end

  test "renders strikethrough" do
    markdown = "~~strikethrough~~"
    result = render_markdown(markdown)

    assert_match(/<del/, result)
    assert_match(/strikethrough/, result)
  end

  test "renders tables" do
    markdown = "| Header |\n|--------|\n| Cell   |"
    result = render_markdown(markdown)

    assert_match(/<table/, result)
    assert_match(/Header/, result)
    assert_match(/Cell/, result)
  end

  test "renders task lists" do
    markdown = "- [ ] Todo item\n- [x] Done item"
    result = render_markdown(markdown)

    assert_match(/<input/, result)
    assert_match(/type="checkbox"/, result)
  end

  test "renders autolinks" do
    markdown = "Visit https://example.com"
    result = render_markdown(markdown)

    assert_match(/<a/, result)
    assert_match(/https:\/\/example.com/, result)
  end
end
