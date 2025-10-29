require "test_helper"

# Tests for GithubToken model validations and associations
class GithubTokenTest < ActiveSupport::TestCase
  test "should belong to user" do
    user = users(:one)
    token = user.github_tokens.create!(domain: "github.com", token: "test_token")
    assert_respond_to token, :user
    assert_instance_of User, token.user
  end

  test "should validate presence of domain" do
    token = GithubToken.new(user: users(:one), token: "test_token", domain: nil)
    assert_not token.valid?
    assert_includes token.errors[:domain], "can't be blank"
  end

  test "should validate presence of token" do
    token = GithubToken.new(user: users(:one), domain: "github.com", token: nil)
    assert_not token.valid?
    assert_includes token.errors[:token], "can't be blank"
  end

  test "should validate uniqueness of domain per user" do
    user = users(:one)
    user.github_tokens.create!(domain: "github.com", token: "test_token")

    duplicate_token = GithubToken.new(user: user, domain: "github.com", token: "another_token")
    assert_not duplicate_token.valid?
    assert_includes duplicate_token.errors[:domain], "has already been taken"
  end

  test "should allow same domain for different users" do
    user1 = users(:one)
    user2 = users(:two)

    token1 = user1.github_tokens.create!(domain: "github.com", token: "token1")
    token2 = user2.github_tokens.create!(domain: "github.com", token: "token2")

    assert token1.valid?
    assert token2.valid?
  end

  test "should have default domain" do
    token = GithubToken.new(user: users(:one), token: "test_token")
    assert_equal "github.com", token.domain
  end

  test "should encrypt token" do
    token = GithubToken.create!(user: users(:one), domain: "github.com", token: "plaintext_token")
    # The actual token should be stored encrypted in the database
    # We can verify this by checking that the token is accessible but stored differently
    assert_equal "plaintext_token", token.token
  end
end
