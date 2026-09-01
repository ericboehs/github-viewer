require "test_helper"

# Tests the SessionsController controller
class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email_address: "test@example.com",
      password: "password123"
    )
  end

  # Return-to-after-authenticating

  test "should return to the page the user was trying to reach" do
    repository = @user.repositories.create!(
      github_domain: "github.com", owner: "rails", name: "rails",
      full_name: "rails/rails", url: "https://github.com/rails/rails"
    )

    get repository_issues_url(repository)

    assert_redirected_to new_session_url

    post session_url, params: { email_address: @user.email_address, password: "password123" }

    assert_redirected_to repository_issues_url(repository)
  end

  # Regression: background `fetch` calls keep firing on an open page after the
  # session expires. Storing a JSON endpoint as the return-to location meant
  # the next successful sign-in dumped the user on a raw JSON blob instead of
  # the page they were looking at.
  test "should not return to a JSON endpoint after signing in" do
    repository = @user.repositories.create!(
      github_domain: "github.com", owner: "rails", name: "rails",
      full_name: "rails/rails", url: "https://github.com/rails/rails"
    )

    get assignable_users_repository_url(repository), as: :json

    assert_redirected_to new_session_url

    post session_url, params: { email_address: @user.email_address, password: "password123" }

    assert_redirected_to root_url
  end

  test "should not return to a page requested by a background XHR" do
    repository = @user.repositories.create!(
      github_domain: "github.com", owner: "rails", name: "rails",
      full_name: "rails/rails", url: "https://github.com/rails/rails"
    )

    get repository_issues_url(repository), headers: { "X-Requested-With" => "XMLHttpRequest" }

    assert_redirected_to new_session_url

    post session_url, params: { email_address: @user.email_address, password: "password123" }

    assert_redirected_to root_url
  end

  test "should get new" do
    get new_session_url
    assert_response :success
    assert_select "h1", "Sign in to your account"
  end

  test "should create session with valid credentials" do
    post session_url, params: {
      email_address: @user.email_address,
      password: "password123"
    }

    assert_redirected_to root_url
    assert_not_nil cookies[:session_id]
  end

  test "should not create session with invalid credentials" do
    post session_url, params: {
      email_address: @user.email_address,
      password: "wrongpassword"
    }

    assert_redirected_to new_session_url
    assert_equal "Invalid email or password", flash[:alert]
  end

  test "should not create session with non-existent user" do
    post session_url, params: {
      email_address: "nonexistent@example.com",
      password: "password123"
    }

    assert_redirected_to new_session_url
    assert_equal "Invalid email or password", flash[:alert]
  end

  test "should destroy session" do
    # First sign in
    post session_url, params: {
      email_address: @user.email_address,
      password: "password123"
    }

    # Then sign out
    delete session_url
    assert_redirected_to new_session_url
  end

  test "should redirect to intended URL after authentication" do
    # Try to access protected page
    get user_url
    assert_redirected_to new_session_url

    # Sign in
    post session_url, params: {
      email_address: @user.email_address,
      password: "password123"
    }

    # Should redirect to originally requested page
    assert_redirected_to user_url
  end
end
