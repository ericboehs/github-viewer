# frozen_string_literal: true

require "test_helper"

# Tests the Auth::FormContainerComponent component
class Auth::FormContainerComponentTest < ViewComponent::TestCase
  def test_renders_with_title_key
    component = Auth::FormContainerComponent.new(title_key: "auth.sign_in.title")
    render_inline(component) { "Form content" }

    assert_selector "h1", text: "Sign in to your account"
    assert_text "Form content"
    assert_selector ".flex.min-h-full.flex-col"
  end

  def test_renders_with_title_and_subtitle
    component = Auth::FormContainerComponent.new(
      title_key: "auth.sign_in.title",
      title: "Custom Title",
      subtitle: "Custom Subtitle"
    )
    render_inline(component) { "Form content" }

    assert_selector "h1", text: "Custom Title"
    assert_selector "p", text: "Custom Subtitle"
  end

  def test_renders_logo
    component = Auth::FormContainerComponent.new(title_key: "auth.sign_in.title")
    render_inline(component) { "Form content" }

    # GitHub logo SVG should be present
    assert_selector "svg"
    assert_selector "svg path[d*='M8 0C3.58']" # Check for GitHub logo path
  end

  def test_renders_with_title_key_only
    component = Auth::FormContainerComponent.new(title_key: "auth.sign_up.title")
    render_inline(component) { "Form content" }

    assert_selector "h1", text: "Create your account"
    assert_text "Form content"
  end

  def test_renders_with_subtitle_key
    component = Auth::FormContainerComponent.new(
      title_key: "auth.sign_in.title",
      subtitle_key: "auth.sign_in.subtitle"
    )
    render_inline(component) { "Form content" }

    assert_selector "h1", text: "Sign in to your account"
    assert_selector "p", text: "Welcome back to GithubViewer"
  end

  def test_renders_with_nil_title_key
    component = Auth::FormContainerComponent.new(
      title_key: nil,
      title: "Custom Title"
    )
    render_inline(component) { "Form content" }

    assert_selector "h1", text: "Custom Title"
    assert_text "Form content"
  end

  def test_renders_without_title_when_both_nil
    component = Auth::FormContainerComponent.new(
      title_key: nil,
      title: nil
    )
    render_inline(component) { "Form content" }

    # Should still render the form content even without a title
    assert_text "Form content"
  end

  def test_renders_without_subtitle_when_both_nil
    component = Auth::FormContainerComponent.new(
      title_key: "auth.sign_in.title",
      subtitle_key: nil,
      subtitle: nil
    )
    render_inline(component) { "Form content" }

    # Should render title but not subtitle
    assert_selector "h1", text: "Sign in to your account"
    assert_no_selector "p.mt-2"
  end
end
