# frozen_string_literal: true

require "test_helper"

module FilterDropdown
  class ItemComponentTest < ViewComponent::TestCase
    test "renders basic item with text" do
      render_inline(FilterDropdown::ItemComponent.new(text: "Test Item"))

      assert_selector "button[role='menuitem']"
      assert_text "Test Item"
      assert_selector "button[data-value='Test Item']"
    end

    test "renders item with custom value" do
      render_inline(FilterDropdown::ItemComponent.new(text: "Display Text", value: "custom_value"))

      assert_text "Display Text"
      assert_selector "button[data-value='custom_value']"
    end

    test "renders item with avatar" do
      render_inline(FilterDropdown::ItemComponent.new(
        text: "User Name",
        avatar_url: "https://example.com/avatar.png"
      ))

      assert_selector "img[src='https://example.com/avatar.png']"
      assert_selector "img[alt='User Name']"
    end

    test "renders item with user icon when no avatar" do
      render_inline(FilterDropdown::ItemComponent.new(text: "No Avatar", icon: :user))

      assert_selector "svg"
      assert_selector "svg path[d*='M8 8a3']"
    end

    test "renders selected item with checkmark" do
      render_inline(FilterDropdown::ItemComponent.new(text: "Selected Item", selected: true))

      assert_selector "svg.text-blue-600"
      assert_selector "svg path[d*='M13.78 4.22']"
    end

    test "does not render checkmark for unselected item" do
      render_inline(FilterDropdown::ItemComponent.new(text: "Unselected Item", selected: false))

      assert_no_selector "svg.text-blue-600"
    end

    test "applies selected styling" do
      render_inline(FilterDropdown::ItemComponent.new(text: "Selected", selected: true))

      assert_selector "button.bg-gray-50"
    end
  end
end
