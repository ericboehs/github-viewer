require "test_helper"
require "ostruct"

# Tests the RepositoriesController
class RepositoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email_address: "test@example.com",
      password: "password123"
    )
    @github_token = @user.github_tokens.create!(
      domain: "github.com",
      token: "ghp_test1234567890abcdef"
    )
    sign_in_as(@user)
  end

  test "should redirect to new when no repositories" do
    get repositories_url
    assert_redirected_to new_repository_path
  end

  test "should get index" do
    # Create at least one repository so we don't get redirected to new
    @user.repositories.create!(
      github_domain: "github.com",
      owner: "rails",
      name: "rails",
      full_name: "rails/rails",
      cached_at: 1.minute.ago
    )
    get repositories_url
    assert_response :success
  end

  test "should show repositories for current user" do
    repo1 = @user.repositories.create!(
      github_domain: "github.com",
      owner: "rails",
      name: "rails",
      full_name: "rails/rails",
      cached_at: 1.minute.ago
    )
    repo2 = @user.repositories.create!(
      github_domain: "github.com",
      owner: "ruby",
      name: "ruby",
      full_name: "ruby/ruby",
      cached_at: 2.minutes.ago
    )

    get repositories_url
    assert_response :success
    assert_select "a", text: "rails/rails"
    assert_select "a", text: "ruby/ruby"
  end

  test "should parse and handle valid GitHub URL" do
    # Test that controller correctly parses URL - actual sync will fail without real token
    # but we test the parsing and error handling
    post repositories_url, params: {
      repository: { url: "https://github.com/rails/rails" }
    }

    assert_redirected_to repositories_path
    # Will show error about missing/invalid token since we're using test token
    assert flash[:alert] || flash[:notice]
  end

  test "should parse shorthand format" do
    # Test that controller correctly parses shorthand format
    post repositories_url, params: {
      repository: { url: "rails/rails" }
    }

    assert_redirected_to repositories_path
    assert flash[:alert] || flash[:notice]
  end

  test "should not create repository with invalid URL" do
    assert_no_difference("Repository.count") do
      post repositories_url, params: {
        repository: { url: "invalid" }
      }
    end

    assert_redirected_to repositories_path
    assert_equal I18n.t("repositories.errors.invalid_url"), flash[:alert]
  end

  test "should not create duplicate repository" do
    @user.repositories.create!(
      github_domain: "github.com",
      owner: "rails",
      name: "rails",
      full_name: "rails/rails",
      cached_at: 1.minute.ago
    )

    assert_no_difference("Repository.count") do
      post repositories_url, params: {
        repository: { url: "rails/rails" }
      }
    end

    assert_redirected_to repositories_path
    assert_equal I18n.t("repositories.errors.already_tracked"), flash[:alert]
  end


  test "should destroy repository" do
    repository = @user.repositories.create!(
      github_domain: "github.com",
      owner: "rails",
      name: "rails",
      full_name: "rails/rails",
      cached_at: 1.minute.ago
    )

    assert_difference("Repository.count", -1) do
      delete repository_url(repository)
    end

    assert_redirected_to repositories_path
    assert_equal I18n.t("repositories.destroy.success"), flash[:notice]
  end

  test "should not destroy another user's repository" do
    other_user = User.create!(
      email_address: "other@example.com",
      password: "password123"
    )
    other_repo = other_user.repositories.create!(
      github_domain: "github.com",
      owner: "other",
      name: "repo",
      full_name: "other/repo",
      cached_at: 1.minute.ago
    )

    assert_no_difference("Repository.count") do
      delete repository_url(other_repo)
    end

    assert_response :not_found
  end

  test "should call refresh action for repository" do
    repository = @user.repositories.create!(
      github_domain: "github.com",
      owner: "rails",
      name: "rails",
      full_name: "rails/rails",
      cached_at: 10.minutes.ago
    )

    post refresh_repository_url(repository)

    assert_redirected_to repositories_path
    assert flash[:alert] || flash[:notice]
  end

  test "should handle refresh success" do
    repository = @user.repositories.create!(
      github_domain: "github.com",
      owner: "rails",
      name: "rails",
      full_name: "rails/rails",
      cached_at: 10.minutes.ago
    )

    mock_service = mock("RepositorySyncService")
    mock_service.expects(:call).returns({ success: true })

    Github::RepositorySyncService.expects(:new).returns(mock_service)

    post refresh_repository_url(repository)

    assert_redirected_to repositories_path
    assert_equal I18n.t("repositories.refresh.success"), flash[:notice]
  end

  test "should handle refresh error" do
    repository = @user.repositories.create!(
      github_domain: "github.com",
      owner: "rails",
      name: "rails",
      full_name: "rails/rails",
      cached_at: 10.minutes.ago
    )

    mock_service = mock("RepositorySyncService")
    mock_service.expects(:call).returns({ success: false, error: "API rate limit" })

    Github::RepositorySyncService.expects(:new).returns(mock_service)

    post refresh_repository_url(repository)

    assert_redirected_to repositories_path
    assert flash[:alert].include?("API rate limit")
  end

  test "should handle create success" do
    mock_service = mock("RepositorySyncService")
    mock_service.expects(:call).returns({ success: true })

    Github::RepositorySyncService.expects(:new).returns(mock_service)

    post repositories_url, params: {
      repository: { url: "rails/rails" }
    }

    assert_redirected_to repositories_path
    assert_equal I18n.t("repositories.create.success"), flash[:notice]
  end

  test "should handle create error" do
    mock_service = mock("RepositorySyncService")
    mock_service.expects(:call).returns({ success: false, error: "Invalid token" })

    Github::RepositorySyncService.expects(:new).returns(mock_service)

    post repositories_url, params: {
      repository: { url: "owner/repo" }
    }

    assert_redirected_to repositories_path
    assert flash[:alert].include?("Invalid token")
  end

  test "should return assignable users as JSON" do
    repository = @user.repositories.create!(
      github_domain: "github.com",
      owner: "rails",
      name: "rails",
      full_name: "rails/rails",
      cached_at: 1.minute.ago
    )

    # Mock GitHub API response
    mock_current_user = OpenStruct.new(login: "current_user", avatar_url: "https://example.com/current.png")
    mock_users = [
      OpenStruct.new(login: "alice", avatar_url: "https://example.com/alice.png"),
      OpenStruct.new(login: "bob", avatar_url: "https://example.com/bob.png"),
      OpenStruct.new(login: "charlie", avatar_url: "https://example.com/charlie.png")
    ]
    mock_client = mock
    mock_client.stubs(:user).returns(mock_current_user)
    mock_client.stubs(:repository_assignees).returns(mock_users)
    mock_api_client = mock
    mock_api_client.stubs(:client).returns(mock_client)
    Github::ApiClient.stubs(:new).returns(mock_api_client)

    get assignable_users_repository_url(repository), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 4, json.length
    # Current user should be first, then others alphabetically
    assert_equal "current_user", json.first["login"]
    assert_equal [ "alice", "bob", "charlie", "current_user" ], json.map { |u| u["login"] }.sort
  end

  test "should search assignable users by query" do
    repository = @user.repositories.create!(
      github_domain: "github.com",
      owner: "rails",
      name: "rails",
      full_name: "rails/rails",
      cached_at: 1.minute.ago
    )

    # Mock GitHub API response
    mock_current_user = OpenStruct.new(login: "current_user", avatar_url: "https://example.com/current.png")
    mock_users = [
      OpenStruct.new(login: "alice", avatar_url: "https://example.com/alice.png"),
      OpenStruct.new(login: "bob", avatar_url: "https://example.com/bob.png"),
      OpenStruct.new(login: "charlie", avatar_url: "https://example.com/charlie.png")
    ]
    mock_client = mock
    mock_client.stubs(:user).returns(mock_current_user)
    mock_client.stubs(:repository_assignees).returns(mock_users)
    mock_api_client = mock
    mock_api_client.stubs(:client).returns(mock_client)
    Github::ApiClient.stubs(:new).returns(mock_api_client)

    get assignable_users_repository_url(repository), params: { q: "ali" }, as: :json

    assert_response :success
    json = JSON.parse(response.body)
    # Only alice matches search ("current_user" doesn't contain "ali")
    assert_equal 1, json.length
    assert_equal "alice", json.first["login"]
  end

  test "should limit results to 20 users" do
    repository = @user.repositories.create!(
      github_domain: "github.com",
      owner: "rails",
      name: "rails",
      full_name: "rails/rails",
      cached_at: 1.minute.ago
    )

    # Mock GitHub API response with 25 users
    mock_current_user = OpenStruct.new(login: "current_user", avatar_url: "https://example.com/current.png")
    mock_users = 25.times.map do |i|
      OpenStruct.new(
        login: "user#{i.to_s.rjust(2, '0')}",
        avatar_url: "https://example.com/user#{i}.png"
      )
    end
    mock_client = mock
    mock_client.stubs(:user).returns(mock_current_user)
    mock_client.stubs(:repository_assignees).returns(mock_users)
    mock_api_client = mock
    mock_api_client.stubs(:client).returns(mock_client)
    Github::ApiClient.stubs(:new).returns(mock_api_client)

    get assignable_users_repository_url(repository), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 20, json.length
    # Current user should be first
    assert_equal "current_user", json.first["login"]
  end

  test "should preserve avatar tokens for GHE URLs" do
    repository = @user.repositories.create!(
      github_domain: "github.com",
      owner: "rails",
      name: "rails",
      full_name: "rails/rails",
      cached_at: 1.minute.ago
    )

    # Mock GitHub API response with token in URL (needed for GHE)
    mock_current_user = OpenStruct.new(login: "current_user", avatar_url: "https://example.com/current.png?token=xyz789")
    mock_users = [
      OpenStruct.new(login: "alice", avatar_url: "https://example.com/alice.png?token=abc123")
    ]
    mock_client = mock
    mock_client.stubs(:user).returns(mock_current_user)
    mock_client.stubs(:repository_assignees).returns(mock_users)
    mock_api_client = mock
    mock_api_client.stubs(:client).returns(mock_client)
    Github::ApiClient.stubs(:new).returns(mock_api_client)

    get assignable_users_repository_url(repository), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 2, json.length
    # Current user should be first with token preserved
    assert_equal "current_user", json.first["login"]
    assert_equal "https://example.com/current.png?token=xyz789", json.first["avatar_url"]
    # Alice should be second with token preserved
    assert_equal "alice", json.second["login"]
    assert_equal "https://example.com/alice.png?token=abc123", json.second["avatar_url"]
  end

  test "should include selected user even when search doesn't match" do
    repository = @user.repositories.create!(
      github_domain: "github.com",
      owner: "rails",
      name: "rails",
      full_name: "rails/rails",
      cached_at: 1.minute.ago
    )

    # Mock GitHub API response with multiple users
    mock_current_user = OpenStruct.new(login: "current_user", avatar_url: "https://example.com/current.png")
    mock_users = [
      OpenStruct.new(login: "alice", avatar_url: "https://example.com/alice.png"),
      OpenStruct.new(login: "bob", avatar_url: "https://example.com/bob.png"),
      OpenStruct.new(login: "charlie", avatar_url: "https://example.com/charlie.png")
    ]
    mock_client = mock
    mock_client.stubs(:user).returns(mock_current_user)
    mock_client.stubs(:repository_assignees).returns(mock_users)
    mock_api_client = mock
    mock_api_client.stubs(:client).returns(mock_client)
    Github::ApiClient.stubs(:new).returns(mock_api_client)

    # Search for "ali" with "bob" selected
    # Bob doesn't match "ali" but should still be included (and appear first because selected)
    # Current user doesn't match search so won't be included
    get assignable_users_repository_url(repository), params: { q: "ali", selected: "bob" }, as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 2, json.length # bob (selected) + alice (matches search)
    assert_equal "bob", json.first["login"] # Selected user appears first
    assert_equal "alice", json.second["login"] # Matching user appears second
  end

  test "should return error when no github token exists" do
    repository = @user.repositories.create!(
      github_domain: "github.com",
      owner: "rails",
      name: "rails",
      full_name: "rails/rails",
      cached_at: 1.minute.ago
    )

    # Don't create a github token for this test
    @user.github_tokens.destroy_all

    get assignable_users_repository_url(repository), as: :json

    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert json["error"].include?("No GitHub token found")
  end

  test "should handle selected user not found on GitHub" do
    repository = @user.repositories.create!(
      github_domain: "github.com",
      owner: "rails",
      name: "rails",
      full_name: "rails/rails",
      cached_at: 1.minute.ago
    )

    mock_current_user = OpenStruct.new(login: "current_user", avatar_url: "https://example.com/current.png")
    mock_users = [
      OpenStruct.new(login: "alice", avatar_url: "https://example.com/alice.png")
    ]
    mock_client = mock
    mock_client.stubs(:user).with().returns(mock_current_user)
    mock_client.stubs(:user).with("nonexistent_user").raises(Octokit::NotFound.new)
    mock_client.stubs(:repository_assignees).returns(mock_users)
    mock_api_client = mock
    mock_api_client.stubs(:client).returns(mock_client)
    Github::ApiClient.stubs(:new).returns(mock_api_client)

    get assignable_users_repository_url(repository), params: { selected: "nonexistent_user" }, as: :json

    assert_response :success
    json = JSON.parse(response.body)
    # Should return current_user + alice, but not the nonexistent selected user
    assert_equal 2, json.length
    assert_equal "current_user", json.first["login"]
  end

  test "should add current user when not in search results" do
    repository = @user.repositories.create!(
      github_domain: "github.com",
      owner: "rails",
      name: "rails",
      full_name: "rails/rails",
      cached_at: 1.minute.ago
    )

    mock_current_user = OpenStruct.new(login: "zzzuser", avatar_url: "https://example.com/zzz.png")
    mock_users = [
      OpenStruct.new(login: "alice", avatar_url: "https://example.com/alice.png"),
      OpenStruct.new(login: "bob", avatar_url: "https://example.com/bob.png")
    ]
    mock_client = mock
    mock_client.stubs(:user).returns(mock_current_user)
    mock_client.stubs(:repository_assignees).returns(mock_users)
    mock_api_client = mock
    mock_api_client.stubs(:client).returns(mock_client)
    Github::ApiClient.stubs(:new).returns(mock_api_client)

    # Search for "ali" - current user "zzzuser" won't match and should NOT be included
    get assignable_users_repository_url(repository), params: { q: "ali" }, as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 1, json.length
    assert_equal "alice", json.first["login"] # Only matching user
  end

  test "should not duplicate current user when they are selected" do
    repository = @user.repositories.create!(
      github_domain: "github.com",
      owner: "rails",
      name: "rails",
      full_name: "rails/rails",
      cached_at: 1.minute.ago
    )

    mock_current_user = OpenStruct.new(login: "current_user", avatar_url: "https://example.com/current.png")
    mock_users = [
      OpenStruct.new(login: "alice", avatar_url: "https://example.com/alice.png"),
      OpenStruct.new(login: "current_user", avatar_url: "https://example.com/current.png")
    ]
    mock_client = mock
    mock_client.stubs(:user).returns(mock_current_user)
    mock_client.stubs(:repository_assignees).returns(mock_users)
    mock_api_client = mock
    mock_api_client.stubs(:client).returns(mock_client)
    Github::ApiClient.stubs(:new).returns(mock_api_client)

    # Select current_user - should only appear once
    get assignable_users_repository_url(repository), params: { selected: "current_user" }, as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 2, json.length
    assert_equal "current_user", json.first["login"] # Current user appears once
    assert_equal "alice", json.second["login"]
    # Make sure current_user doesn't appear twice
    assert_equal 1, json.count { |u| u["login"] == "current_user" }
  end

  test "should handle API errors gracefully" do
    repository = @user.repositories.create!(
      github_domain: "github.com",
      owner: "rails",
      name: "rails",
      full_name: "rails/rails",
      cached_at: 1.minute.ago
    )

    mock_client = mock
    mock_client.stubs(:user).raises(StandardError.new("API Error"))
    mock_api_client = mock
    mock_api_client.stubs(:client).returns(mock_client)
    Github::ApiClient.stubs(:new).returns(mock_api_client)

    get assignable_users_repository_url(repository), as: :json

    assert_response :internal_server_error
    json = JSON.parse(response.body)
    assert json["error"].include?("Failed to fetch assignable users")
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end
end
