require "application_system_test_case"

# Tests keyboard shortcuts functionality on issues index page
class KeyboardShortcutsTest < ApplicationSystemTestCase
  setup do
    @user = User.create!(
      email_address: "test@example.com",
      password: "password123"
    )
    @github_token = @user.github_tokens.create!(
      domain: "github.com",
      token: "ghp_test1234567890abcdef"
    )
    @repository = @user.repositories.create!(
      github_domain: "github.com",
      owner: "rails",
      name: "rails",
      full_name: "rails/rails",
      cached_at: 1.hour.ago
    )

    # Create some test issues
    3.times do |i|
      @repository.issues.create!(
        number: i + 1,
        title: "Test Issue #{i + 1}",
        state: "open",
        github_created_at: (i + 1).days.ago,
        github_updated_at: (i + 1).hours.ago,
        author_login: "testuser#{i + 1}",
        cached_at: 1.hour.ago
      )
    end
  end

  test "pressing question mark shows keyboard shortcuts modal" do
    sign_in
    visit repository_issues_path(@repository)

    # Press ? to open help modal
    page.find("body").send_keys("?")

    # Modal should be visible
    assert_selector "[role='dialog']", visible: true
    assert_text "Keyboard shortcuts"
    assert_text "Navigation"
    assert_text "Next/previous issue"
  end

  test "pressing shift-/ shows keyboard shortcuts modal" do
    sign_in
    visit repository_issues_path(@repository)

    # Press Shift-/ to open help modal
    page.find("body").send_keys([ :shift, "/" ])

    # Modal should be visible
    assert_selector "[role='dialog']", visible: true
    assert_text "Keyboard shortcuts"
  end

  test "pressing escape closes keyboard shortcuts modal" do
    sign_in
    visit repository_issues_path(@repository)

    # Open modal
    page.find("body").send_keys("?")
    assert_selector "[role='dialog']", visible: true

    # Close with Escape
    page.find("[role='dialog']").send_keys(:escape)

    # Modal should be hidden (not visible)
    assert_selector "[role='dialog']", visible: false
  end

  test "pressing forward slash focuses search input" do
    sign_in
    visit repository_issues_path(@repository)

    # Press / to focus search
    page.find("body").send_keys("/")

    # Search input should be focused
    search_input = find("input[name='q']")
    assert_equal search_input, page.evaluate_script("document.activeElement")
  end

  test "issue cards have keyboard shortcuts targets" do
    sign_in
    visit repository_issues_path(@repository)

    # Verify that issue cards have the keyboard shortcuts target attribute
    assert_selector "[data-keyboard-shortcuts-target='issueCard']", count: 3
  end

  test "search input has keyboard shortcuts target" do
    sign_in
    visit repository_issues_path(@repository)

    # Verify that search input has the keyboard shortcuts target attribute
    assert_selector "[data-keyboard-shortcuts-target='searchInput']"
  end

  test "page has keyboard shortcuts controller" do
    sign_in
    visit repository_issues_path(@repository)

    # Verify that the page has the keyboard shortcuts controller
    assert_selector "[data-controller='keyboard-shortcuts']"
  end

  test "keyboard shortcuts modal has data attributes" do
    sign_in
    visit repository_issues_path(@repository)

    # Verify that the keyboard shortcuts modal exists (even though it's hidden by default)
    assert_selector "[data-keyboard-shortcuts-target='modal'][role='dialog']", visible: :all
  end

  private

  def sign_in
    visit new_session_path
    fill_in "Email address", with: @user.email_address
    fill_in "Password", with: "password123"
    click_button "Sign in"
    # Wait for redirect to complete
    assert_current_path root_path, wait: 5
  end
end
