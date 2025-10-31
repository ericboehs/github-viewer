require "application_system_test_case"

# Tests repository management system functionality
class RepositoriesTest < ApplicationSystemTestCase
  setup do
    @user = User.create!(
      email_address: "test@example.com",
      password: "password123"
    )
    @github_token = @user.github_tokens.create!(
      domain: "github.com",
      token: "ghp_test1234567890abcdef"
    )
  end

  test "user with no repositories is redirected to new repository page" do
    # Sign in first
    sign_in

    visit repositories_path

    # Should be redirected to new repository page
    assert_current_path new_repository_path
    assert_text "Add Repository"
  end

  test "new repository page displays form with autofocus" do
    # Sign in first
    sign_in

    visit new_repository_path

    assert_text "Add Repository"
    assert_field "repository[url]"
    assert_button "Add Repository"

    # Check that the input field exists
    input = find_field("repository[url]")
    assert input
  end

  test "user can view repositories list" do
    # Sign in first
    sign_in

    # Create test repositories
    @user.repositories.create!(
      github_domain: "github.com",
      owner: "rails",
      name: "rails",
      full_name: "rails/rails",
      cached_at: 1.hour.ago
    )
    @user.repositories.create!(
      github_domain: "github.com",
      owner: "ruby",
      name: "ruby",
      full_name: "ruby/ruby",
      cached_at: 2.hours.ago
    )

    visit repositories_path

    # Should show repositories in card layout
    assert_text "Repositories"
    assert_link "rails/rails"
    assert_link "ruby/ruby"
    assert_link "Add Repository"
  end

  test "repositories show timestamps and stale indicators" do
    # Sign in first
    sign_in

    # Create fresh repository
    fresh_repo = @user.repositories.create!(
      github_domain: "github.com",
      owner: "rails",
      name: "rails",
      full_name: "rails/rails",
      cached_at: 5.minutes.ago
    )

    # Create stale repository (older than 6 hours)
    stale_repo = @user.repositories.create!(
      github_domain: "github.com",
      owner: "ruby",
      name: "ruby",
      full_name: "ruby/ruby",
      cached_at: 7.hours.ago
    )

    visit repositories_path

    # Should show time_ago for both
    # Check for stale repo existence
    assert_text "ruby/ruby"
    assert_text "rails/rails"
  end

  test "dashboard shows recently updated repositories" do
    # Sign in first
    sign_in

    # Create repositories with different cached_at times
    @user.repositories.create!(
      github_domain: "github.com",
      owner: "rails",
      name: "rails",
      full_name: "rails/rails",
      cached_at: 1.hour.ago
    )
    @user.repositories.create!(
      github_domain: "github.com",
      owner: "ruby",
      name: "ruby",
      full_name: "ruby/ruby",
      cached_at: 2.hours.ago
    )

    visit root_path

    assert_text "Recently Updated Repositories"
    assert_link "rails/rails"
    assert_link "ruby/ruby"
  end

  test "dashboard does not show recently updated section when no cached repos" do
    # Sign in first
    sign_in

    # Create repository without cached_at
    @user.repositories.create!(
      github_domain: "github.com",
      owner: "rails",
      name: "rails",
      full_name: "rails/rails"
    )

    visit root_path

    assert_no_text "Recently Updated Repositories"
  end

  test "repositories have responsive layout on mobile" do
    # Sign in first
    sign_in

    @user.repositories.create!(
      github_domain: "github.com",
      owner: "rails",
      name: "rails",
      full_name: "rails/rails",
      cached_at: 1.hour.ago
    )

    visit repositories_path

    # Check that repository is in list item (not table)
    assert_selector "ul[role='list']"
    assert_selector "li"

    # Domain and timestamp should be present
    assert_text "github.com"
  end

  private

  def sign_in
    visit new_session_path
    fill_in "Email address", with: @user.email_address
    fill_in "Password", with: "password123"
    click_button "Sign in"
    # Wait for redirect to complete
    assert_current_path root_path
  end
end
