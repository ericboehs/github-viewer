# frozen_string_literal: true

require "test_helper"

class IssueStateComponentTest < ViewComponent::TestCase
  test "renders open state with correct styling" do
    render_inline(IssueStateComponent.new(state: "open"))

    assert_selector "span.bg-green-100.text-green-800"
    assert_selector "svg"
    assert_text "Open"
  end

  test "renders closed state with correct styling" do
    render_inline(IssueStateComponent.new(state: "closed"))

    assert_selector "span.bg-purple-100.text-purple-800"
    assert_selector "svg"
    assert_text "Closed"
  end

  test "renders closed state icon" do
    render_inline(IssueStateComponent.new(state: "closed"))

    # Check for the check circle icon path (closed icon)
    assert_selector "svg path[d*='M8 16A8 8 0']"
  end

  test "renders open state icon" do
    render_inline(IssueStateComponent.new(state: "open"))

    # Check for the open circle icon path
    assert_selector "svg path[d*='M8 1.5a6.5']"
  end
end
