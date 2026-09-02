require "test_helper"

# Tests the UsersController controller
class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email_address: "test@example.com",
      password: "password123"
    )
  end

  # Test error cases not covered by system tests
  test "should not create user with invalid params" do
    assert_no_difference("User.count") do
      post users_url, params: {
        user: {
          email_address: "",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should not update user with invalid params" do
    sign_in_as(@user)
    patch user_url, params: {
      user: {
        email_address: ""
      }
    }

    assert_response :unprocessable_entity
  end

  test "should create user with valid params" do
    assert_difference("User.count") do
      post users_url, params: {
        user: {
          email_address: "newuser@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_redirected_to new_session_url
    assert_equal "Account created successfully! Please sign in.", flash[:notice]
  end

  test "should update user with valid params when authenticated" do
    sign_in_as(@user)
    patch user_url, params: {
      user: {
        email_address: "updated@example.com"
      }
    }

    assert_redirected_to user_url
    assert_equal "Profile updated successfully.", flash[:notice]
    @user.reload
    assert_equal "updated@example.com", @user.email_address
  end

  test "should get new" do
    get new_user_url
    assert_response :success
    assert_select "h1", "Create your account"
  end

  test "should show user profile when authenticated" do
    sign_in_as(@user)
    get user_url
    assert_response :success
    assert_select "h1", "Your Profile"
  end

  test "should get edit when authenticated" do
    sign_in_as(@user)
    get edit_user_url
    assert_response :success
    assert_select "h1", "Edit Profile"
  end

  private

  # Regression: the profile page rendered a masked preview by decrypting the
  # token, so an unreadable one 500ed the only page that can remove it.
  test "profile still renders when a token cannot be decrypted" do
    sign_in_as(@user)
    @user.github_tokens.create!(domain: "va.ghe.com", token: "ghp_example_token")
    # Only the persisted row has unreadable ciphertext; the blank record behind
    # the "add token" form must still render normally.
    GithubToken.any_instance.stubs(:readable_token).returns(nil)

    get user_path

    assert_response :success
    assert_match "Unreadable", response.body
  end
end
