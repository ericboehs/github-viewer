# frozen_string_literal: true

require "test_helper"

class IssueLabelComponentTest < ViewComponent::TestCase
  test "renders label with name and color" do
    label = { "name" => "bug", "color" => "d73a4a" }
    render_inline(IssueLabelComponent.new(label: label))

    assert_text "bug"
    # Background is original RGB color (GitHub's light mode algorithm)
    assert_selector "span[style*='background-color: rgb(215, 58, 74)']"
    # Text is white for dark backgrounds (perceived lightness < 0.453)
    assert_selector "span[style*='color: hsl(0, 0%, 100%)']"
    # Border is transparent for dark backgrounds
    assert_selector "span[style*='border-color: transparent']"
  end

  test "renders label with light background and dark text" do
    label = { "name" => "documentation", "color" => "ffffff" }  # White API color
    render_inline(IssueLabelComponent.new(label: label))

    assert_text "documentation"
    # Background is original RGB color
    assert_selector "span[style*='background-color: rgb(255, 255, 255)']"
    # Text is black for light backgrounds (perceived lightness > 0.453)
    assert_selector "span[style*='color: hsl(0, 0%, 0%)']"
    # Border is muted gray for very light backgrounds (perceived lightness > 0.96)
    assert_selector "span[style*='border-color: var(--color-border-muted']"
  end

  test "renders label with dark background and light text" do
    label = { "name" => "bug", "color" => "000000" }  # Black API color
    render_inline(IssueLabelComponent.new(label: label))

    assert_text "bug"
    # Background is original RGB color (black)
    assert_selector "span[style*='background-color: rgb(0, 0, 0)']"
    # Text is white for dark backgrounds (perceived lightness = 0)
    assert_selector "span[style*='color: hsl(0, 0%, 100%)']"
    # Border is transparent for dark backgrounds
    assert_selector "span[style*='border-color: transparent']"
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
    # Background is original RGB color
    assert_selector "span[style*='background-color: rgb(162, 238, 239)']"
    # Text is black for light backgrounds (perceived lightness > 0.453)
    assert_selector "span[style*='color: hsl(0, 0%, 0%)']"
    # Border is transparent for this lightness level
    assert_selector "span[style*='border-color: transparent']"
  end

  test "handles label with nil color in text color calculation" do
    label = { "name" => "test", "color" => nil }
    render_inline(IssueLabelComponent.new(label: label))

    # Should render without crashing
    assert_text "test"
  end

  test "renders label as link when repository is provided" do
    user = User.create!(
      email_address: "test@example.com",
      password: "password123",
      github_token: "test_token",
      github_domain: "github.com"
    )
    repository = user.repositories.create!(
      owner: "testuser",
      name: "testrepo",
      full_name: "testuser/testrepo",
      url: "https://github.com/testuser/testrepo",
      github_domain: "github.com"
    )
    label = { "name" => "bug", "color" => "d73a4a" }

    render_inline(IssueLabelComponent.new(label: label, repository: repository, query: ""))

    # Link should be present with label filter (URL encoded)
    assert_selector "a[href*='label%3Abug']"
    assert_text "bug"
  end

  test "renders label with spaces quoted in URL" do
    user = User.create!(
      email_address: "test@example.com",
      password: "password123",
      github_token: "test_token",
      github_domain: "github.com"
    )
    repository = user.repositories.create!(
      owner: "testuser",
      name: "testrepo",
      full_name: "testuser/testrepo",
      url: "https://github.com/testuser/testrepo",
      github_domain: "github.com"
    )
    label = { "name" => "help wanted", "color" => "008672" }

    render_inline(IssueLabelComponent.new(label: label, repository: repository, query: ""))

    # Link should contain label with quoted value (spaces require quotes, URL encoded)
    assert_selector "a"
    link = page.find("a")
    assert_includes link[:href], "label%3A"  # URL encoded "label:"
    assert_text "help wanted"
  end

  test "renders label URL when query only contains label qualifier" do
    user = User.create!(
      email_address: "test@example.com",
      password: "password123",
      github_token: "test_token",
      github_domain: "github.com"
    )
    repository = user.repositories.create!(
      owner: "testuser",
      name: "testrepo",
      full_name: "testuser/testrepo",
      url: "https://github.com/testuser/testrepo",
      github_domain: "github.com"
    )
    label = { "name" => "bug", "color" => "d73a4a" }

    # Query contains only a label qualifier
    render_inline(IssueLabelComponent.new(label: label, repository: repository, query: "label:enhancement"))

    # After removing existing label, query should be empty, so URL should be just label:bug
    assert_selector "a"
    link = page.find("a")
    assert_includes link[:href], "label%3Abug"
    assert_text "bug"
  end
end
