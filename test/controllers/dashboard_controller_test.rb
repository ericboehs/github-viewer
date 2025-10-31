require "test_helper"

# Tests the DashboardController controller
class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "test@example.com", password: "password123")
  end

  test "should get index when authenticated" do
    sign_in_as(@user)
    get root_url

    assert_response :success
  end

  test "should redirect to sign in when not authenticated" do
    get root_url

    assert_redirected_to new_session_url
  end

  test "should display recently updated repositories" do
    sign_in_as(@user)

    # Create repositories with cached_at timestamps
    repo1 = @user.repositories.create!(
      owner: "rails",
      name: "rails",
      full_name: "rails/rails",
      github_domain: "github.com",
      cached_at: 1.hour.ago
    )

    repo2 = @user.repositories.create!(
      owner: "ruby",
      name: "ruby",
      full_name: "ruby/ruby",
      github_domain: "github.com",
      cached_at: 2.hours.ago
    )

    get root_url

    assert_response :success
    assert_select "h2", "Recently Updated Repositories"
    # The repository names appear as link text with additional content
    assert_select "a[href=?]", repository_issues_path(repo1) do |links|
      assert links.any? { |link| link.text.include?("rails/rails") }
    end
    assert_select "a[href=?]", repository_issues_path(repo2) do |links|
      assert links.any? { |link| link.text.include?("ruby/ruby") }
    end
  end

  test "should not display recently updated section when no repos cached" do
    sign_in_as(@user)

    # Create repository without cached_at
    @user.repositories.create!(
      owner: "rails",
      name: "rails",
      full_name: "rails/rails",
      github_domain: "github.com"
    )

    get root_url

    assert_response :success
    assert_select "h2", { text: "Recently Updated Repositories", count: 0 }
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end
end
