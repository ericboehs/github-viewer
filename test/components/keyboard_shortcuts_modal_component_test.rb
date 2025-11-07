# frozen_string_literal: true

require "test_helper"

# Tests the KeyboardShortcutsModalComponent component
class KeyboardShortcutsModalComponentTest < ViewComponent::TestCase
  def test_renders_modal_with_title
    component = KeyboardShortcutsModalComponent.new
    render_inline(component)

    assert_text "Keyboard shortcuts"
    assert_selector "[role='dialog']"
    assert_selector "div[role='dialog']"
  end

  def test_renders_modal_hidden_by_default
    component = KeyboardShortcutsModalComponent.new
    render_inline(component)

    assert_selector ".hidden"
  end

  def test_renders_navigation_shortcuts
    component = KeyboardShortcutsModalComponent.new
    render_inline(component)

    assert_text "Navigation"
    assert_text "Next/previous issue"
    assert_text "Clear focus"
  end

  def test_renders_search_and_filter_shortcuts
    component = KeyboardShortcutsModalComponent.new
    render_inline(component)

    assert_text "Search & Filters"
    assert_text "Focus search bar"
    assert_text "Open assignees filter"
    assert_text "Open labels filter"
    assert_text "Open authors filter"
  end

  def test_renders_help_shortcuts
    component = KeyboardShortcutsModalComponent.new
    render_inline(component)

    assert_text "Help"
    assert_text "Show/hide keyboard shortcuts"
  end

  def test_renders_keyboard_keys
    component = KeyboardShortcutsModalComponent.new
    render_inline(component)

    # Check for kbd elements
    assert_selector "kbd", minimum: 1
  end

  def test_renders_close_button
    component = KeyboardShortcutsModalComponent.new
    render_inline(component)

    assert_selector "button[data-action='click->keyboard-shortcuts#closeHelp']"
    # The button should exist and have SVG content
    assert_selector "button svg"
  end

  def test_modal_has_keyboard_shortcuts_target
    component = KeyboardShortcutsModalComponent.new
    render_inline(component)

    assert_selector "[data-keyboard-shortcuts-target='modal']"
  end

  def test_modal_closes_on_escape
    component = KeyboardShortcutsModalComponent.new
    render_inline(component)

    assert_selector "[data-action*='keydown.esc->keyboard-shortcuts#closeHelp']"
  end

  def test_modal_closes_on_outside_click
    component = KeyboardShortcutsModalComponent.new
    render_inline(component)

    assert_selector "[data-action*='click->keyboard-shortcuts#closeOnOutside']"
  end
end
