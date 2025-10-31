# frozen_string_literal: true

require "test_helper"

class IssueStateComponentTest < ViewComponent::TestCase
  test "renders open state with text and correct styling" do
    render_inline(IssueStateComponent.new(state: "open", show_text: true))

    assert_selector "span.bg-green-200.text-green-900"
    assert_selector "svg"
    assert_text "Open"
  end

  test "renders closed state with text and correct styling" do
    render_inline(IssueStateComponent.new(state: "closed", show_text: true))

    assert_selector "span.bg-purple-200.text-purple-900"
    assert_selector "svg"
    assert_text "Closed"
  end

  test "renders icon only without background styling" do
    render_inline(IssueStateComponent.new(state: "open"))

    assert_selector "span.text-green-600"
    assert_selector "svg"
    assert_no_text "Open"
  end

  test "renders closed state icon with GitHub octicon" do
    render_inline(IssueStateComponent.new(state: "closed"))

    # Check for the GitHub octicon closed icon paths
    assert_selector "svg path[d*='M11.28 6.78']"
    assert_selector "svg path[d*='M16 8A8 8 0 1 1 0 8']"
  end

  test "renders open state icon with GitHub octicon" do
    render_inline(IssueStateComponent.new(state: "open"))

    # Check for the GitHub octicon open icon paths
    assert_selector "svg path[d*='M8 9.5a1.5']"
    assert_selector "svg path[d*='M8 0a8 8 0 1 1 0 16']"
  end
end
