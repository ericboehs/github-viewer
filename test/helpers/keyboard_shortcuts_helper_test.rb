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

  # mac_platform? drives the Cmd-/ vs Ctrl-/ label in every shortcut set

  test "shortcuts use Cmd-/ on macOS user agents" do
    request.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"

    [ issue_shortcuts, repository_shortcuts, base_shortcuts ].each do |shortcuts|
      search = shortcuts.find { |cat| cat[:category].start_with?("Search") }
      focus = search[:items].find { |item| item[:description] == "Focus search bar" }
      assert_equal [ "Cmd-/" ], focus[:keys]
    end
  end

  test "shortcuts use Ctrl-/ on non-macOS user agents" do
    request.user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"

    [ issue_shortcuts, repository_shortcuts, base_shortcuts ].each do |shortcuts|
      search = shortcuts.find { |cat| cat[:category].start_with?("Search") }
      focus = search[:items].find { |item| item[:description] == "Focus search bar" }
      assert_equal [ "Ctrl-/" ], focus[:keys]
    end
  end

  test "shortcuts fall back to Ctrl-/ when no request is available" do
    self.stubs(:request).raises(NoMethodError)

    search = base_shortcuts.find { |cat| cat[:category] == "Search" }
    focus = search[:items].find { |item| item[:description] == "Focus search bar" }
    assert_equal [ "Ctrl-/" ], focus[:keys]
  end
end
