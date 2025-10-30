# frozen_string_literal: true

require "test_helper"

class IssueLabelComponentTest < ViewComponent::TestCase
  test "renders label with name and color" do
    label = { "name" => "bug", "color" => "d73a4a" }
    render_inline(IssueLabelComponent.new(label: label))

    assert_text "bug"
    assert_selector "span[style*='background-color: #d73a4a']"
  end

  test "renders label with light background and dark text" do
    label = { "name" => "documentation", "color" => "ffffff" }  # White background
    render_inline(IssueLabelComponent.new(label: label))

    assert_text "documentation"
    # White background should get black text
    assert_selector "span[style*='color: #000000']"
  end

  test "renders label with dark background and light text" do
    label = { "name" => "bug", "color" => "000000" }  # Black background
    render_inline(IssueLabelComponent.new(label: label))

    assert_text "bug"
    # Black background should get white text
    assert_selector "span[style*='color: #FFFFFF']"
  end

  test "renders label without color" do
    label = { "name" => "needs triage", "color" => nil }
    render_inline(IssueLabelComponent.new(label: label))

    assert_text "needs triage"
  end

  test "renders label with symbol keys" do
    label = { name: "enhancement", color: "a2eeef" }
    render_inline(IssueLabelComponent.new(label: label))

    assert_text "enhancement"
    assert_selector "span[style*='background-color: #a2eeef']"
  end

  test "handles label with nil color in text color calculation" do
    label = { "name" => "test", "color" => nil }
    render_inline(IssueLabelComponent.new(label: label))

    # Should render without crashing
    assert_text "test"
  end
end
