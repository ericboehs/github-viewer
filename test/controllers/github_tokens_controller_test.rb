require "test_helper"

# Tests the GithubTokensController controller
class GithubTokensControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email_address: "test@example.com",
      password: "password123"
    )
    sign_in_as(@user)
  end

  test "should create github token with valid params" do
    assert_difference("GithubToken.count") do
      post github_tokens_url, params: {
        github_token: {
          domain: "github.com",
          token: "ghp_test1234567890abcdef"
        }
      }
    end

    assert_redirected_to user_path
    assert_equal "GitHub token added successfully.", flash[:notice]

    token = @user.github_tokens.last
    assert_equal "github.com", token.domain
  end

  test "should not create github token with missing domain" do
    assert_no_difference("GithubToken.count") do
      post github_tokens_url, params: {
        github_token: {
          domain: "",
          token: "ghp_test1234567890abcdef"
        }
      }
    end

    assert_redirected_to user_path
    assert_match(/Failed to add token/, flash[:alert])
  end

  test "should not create github token with missing token" do
    assert_no_difference("GithubToken.count") do
      post github_tokens_url, params: {
        github_token: {
          domain: "github.com",
          token: ""
        }
      }
    end

    assert_redirected_to user_path
    assert_match(/Failed to add token/, flash[:alert])
  end

  test "should not create duplicate github token for same domain" do
    @user.github_tokens.create!(
      domain: "github.com",
      token: "ghp_existing1234567890abcdef"
    )

    assert_no_difference("GithubToken.count") do
      post github_tokens_url, params: {
        github_token: {
          domain: "github.com",
          token: "ghp_newtoken1234567890abcdef"
        }
      }
    end

    assert_redirected_to user_path
    assert_match(/Failed to add token/, flash[:alert])
  end

  test "should destroy github token" do
    token = @user.github_tokens.create!(
      domain: "github.com",
      token: "ghp_test1234567890abcdef"
    )

    assert_difference("GithubToken.count", -1) do
      delete github_token_url(token)
    end

    assert_redirected_to user_path
    assert_equal "GitHub token removed successfully.", flash[:notice]
  end

  test "should not destroy another user's github token" do
    other_user = User.create!(
      email_address: "other@example.com",
      password: "password123"
    )
    other_token = other_user.github_tokens.create!(
      domain: "github.com",
      token: "ghp_other1234567890abcdef"
    )

    assert_no_difference("GithubToken.count") do
      delete github_token_url(other_token)
    end

    assert_response :not_found
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end
end
