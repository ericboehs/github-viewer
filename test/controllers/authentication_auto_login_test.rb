require "test_helper"

# Development-only auto sign-in on localhost.
class AuthenticationAutoLoginTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  def in_development
    Rails.stubs(:env).returns(ActiveSupport::StringInquirer.new("development"))
    yield
  end

  test "signs in automatically on localhost in development" do
    in_development do
      get root_url

      assert_response :success
      assert Session.exists?(user: User.first), "expected a session to be created"
    end
  end

  # The whole point of the gate: a deployed instance must never do this.
  test "does not auto sign in outside development" do
    get root_url

    assert_redirected_to new_session_path
  end

  test "does not auto sign in for a non-local request" do
    in_development do
      get root_url, headers: { "REMOTE_ADDR" => "203.0.113.7" }

      assert_redirected_to new_session_path
    end
  end

  test "DEV_AUTO_LOGIN=0 restores the real sign in flow" do
    in_development do
      ENV["DEV_AUTO_LOGIN"] = "0"
      get root_url

      assert_redirected_to new_session_path
    ensure
      ENV.delete("DEV_AUTO_LOGIN")
    end
  end

  test "DEV_AUTO_LOGIN_EMAIL picks the user" do
    other = User.create!(email_address: "someone@example.com", password: "password123")
    in_development do
      ENV["DEV_AUTO_LOGIN_EMAIL"] = other.email_address
      get root_url

      assert_response :success
      assert Session.exists?(user: other), "expected the named user to be signed in"
    ensure
      ENV.delete("DEV_AUTO_LOGIN_EMAIL")
    end
  end

  test "does not auto sign in a user who just signed out" do
    in_development do
      get root_url
      assert_response :success

      delete session_url
      assert_redirected_to new_session_path

      get root_url
      assert_redirected_to new_session_path, "signing out should stick"
    end
  end

  # Suppression must not block a real sign-in, and signing in must clear it so
  # auto-login resumes afterwards.
  test "signing in manually clears the suppression" do
    in_development do
      get root_url
      delete session_url

      post session_url, params: { email_address: @user.email_address, password: "password123" }
      assert_redirected_to root_url

      # Losing the session cookie should now auto-login again rather than
      # bouncing to the form.
      cookies.delete("session_id")
      get root_url
      assert_response :success
    end
  end
end
