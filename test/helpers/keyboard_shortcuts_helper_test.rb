# frozen_string_literal: true

require "test_helper"

class KeyboardShortcutsHelperTest < ActionView::TestCase
  test "issue_shortcuts returns array of shortcut categories" do
    shortcuts = issue_shortcuts
    assert_kind_of Array, shortcuts
    assert_equal 3, shortcuts.length
  end

  test "issue_shortcuts includes navigation category" do
    shortcuts = issue_shortcuts
    navigation = shortcuts.find { |cat| cat[:category] == "Navigation" }
    assert_not_nil navigation
    assert_kind_of Array, navigation[:items]
  end

  test "issue_shortcuts includes search and filters category" do
    shortcuts = issue_shortcuts
    search = shortcuts.find { |cat| cat[:category] == "Search & Filters" }
    assert_not_nil search
    assert_kind_of Array, search[:items]
  end

  test "issue_shortcuts includes help category" do
    shortcuts = issue_shortcuts
    help = shortcuts.find { |cat| cat[:category] == "Help" }
    assert_not_nil help
    assert_kind_of Array, help[:items]
  end

  test "repository_shortcuts returns array of shortcut categories" do
    shortcuts = repository_shortcuts
    assert_kind_of Array, shortcuts
    assert_equal 3, shortcuts.length
  end

  test "repository_shortcuts includes navigation category" do
    shortcuts = repository_shortcuts
    navigation = shortcuts.find { |cat| cat[:category] == "Navigation" }
    assert_not_nil navigation
    assert_includes navigation[:items].first[:description], "repository"
  end

  test "repository_shortcuts includes search category" do
    shortcuts = repository_shortcuts
    search = shortcuts.find { |cat| cat[:category] == "Search" }
    assert_not_nil search
    assert_kind_of Array, search[:items]
  end

  test "base_shortcuts returns array of shortcut categories" do
    shortcuts = base_shortcuts
    assert_kind_of Array, shortcuts
    assert_equal 3, shortcuts.length
  end

  test "base_shortcuts includes navigation category" do
    shortcuts = base_shortcuts
    navigation = shortcuts.find { |cat| cat[:category] == "Navigation" }
    assert_not_nil navigation
    assert_includes navigation[:items].first[:description], "item"
  end

  test "base_shortcuts includes search category" do
    shortcuts = base_shortcuts
    search = shortcuts.find { |cat| cat[:category] == "Search" }
    assert_not_nil search
    assert_kind_of Array, search[:items]
  end

  test "shortcuts include keyboard keys" do
    shortcuts = issue_shortcuts
    navigation = shortcuts.find { |cat| cat[:category] == "Navigation" }
    first_item = navigation[:items].first
    assert_kind_of Array, first_item[:keys]
    assert first_item[:keys].length > 0
  end

  test "shortcuts include descriptions" do
    shortcuts = issue_shortcuts
    navigation = shortcuts.find { |cat| cat[:category] == "Navigation" }
    first_item = navigation[:items].first
    assert_kind_of String, first_item[:description]
    assert first_item[:description].length > 0
  end
end
