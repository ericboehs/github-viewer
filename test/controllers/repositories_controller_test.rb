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

  # Assignable users (filter dropdown data source)
  #
  # Served from the locally synced repository_assignable_users table. These
  # used to mock the REST API, which is exactly what made the endpoint slow.

  def repo_with_assignees(*logins, synced_at: Time.current)
    repository = @user.repositories.create!(
      github_domain: "github.com", owner: "rails", name: "rails",
      full_name: "rails/rails", cached_at: 1.minute.ago
    )
    logins.each do |login|
      repository.repository_assignable_users.create!(
        login: login, avatar_url: "https://example.com/#{login}.png"
      )
    end
    repository.repository_assignable_users.update_all(updated_at: synced_at)
    repository
  end

  # No token means no viewer to pin and no sync to run; the stored list is
  # still perfectly searchable.
  def stub_no_viewer
    @user.github_tokens.destroy_all
    Rails.cache.clear
  end

  def stub_viewer_login(login)
    Rails.cache.clear
    @user.github_tokens.find_or_create_by!(domain: "github.com") { |t| t.token = "ghp_test_token" }
    mock_client = mock
    mock_client.stubs(:user).returns(OpenStruct.new(login: login))
    mock_api_client = mock
    mock_api_client.stubs(:client).returns(mock_client)
    mock_api_client.stubs(:search_assignable_users).returns([])
    Github::ApiClient.stubs(:new).returns(mock_api_client)
  end

  test "should return assignable users as JSON" do
    repository = repo_with_assignees("alice", "bob", "charlie")
    stub_no_viewer

    get assignable_users_repository_url(repository), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal [ "alice", "bob", "charlie" ], json.map { |u| u["login"] }
  end

  test "should search assignable users by query" do
    repository = repo_with_assignees("alice", "bob", "charlie")
    stub_no_viewer

    get assignable_users_repository_url(repository), params: { q: "ali" }, as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal [ "alice" ], json.map { |u| u["login"] }
  end

  test "should limit results to 20 users" do
    repository = repo_with_assignees(*25.times.map { |i| "user#{i.to_s.rjust(2, '0')}" })
    stub_no_viewer

    get assignable_users_repository_url(repository), as: :json

    assert_response :success
    assert_equal 20, JSON.parse(response.body).length
  end

  test "should preserve avatar tokens for GHE URLs" do
    repository = repo_with_assignees("alice")
    repository.repository_assignable_users
              .find_by(login: "alice")
              .update!(avatar_url: "https://example.com/alice.png?token=abc123")
    stub_no_viewer

    get assignable_users_repository_url(repository), as: :json

    json = JSON.parse(response.body)
    assert_equal "https://example.com/alice.png?token=abc123", json.first["avatar_url"]
  end

  test "should include selected user even when search does not match" do
    repository = repo_with_assignees("alice", "bob")
    stub_no_viewer

    get assignable_users_repository_url(repository), params: { q: "ali", selected: "bob" }, as: :json

    json = JSON.parse(response.body)
    assert_equal "bob", json.first["login"]
    assert_equal [ "bob", "alice" ], json.map { |u| u["login"] }
  end

  test "should include a selected user who is not in the synced list" do
    repository = repo_with_assignees("alice")
    stub_no_viewer

    get assignable_users_repository_url(repository), params: { selected: "ghost" }, as: :json

    json = JSON.parse(response.body)
    assert_equal "ghost", json.first["login"]
    assert_nil json.first["avatar_url"]
  end

  test "should pin the viewer above other matches" do
    repository = repo_with_assignees("alice", "current_user")
    stub_viewer_login("current_user")

    get assignable_users_repository_url(repository), as: :json

    json = JSON.parse(response.body)
    assert_equal "current_user", json.first["login"]
    assert_equal [ "current_user", "alice" ], json.map { |u| u["login"] }
  end

  test "should not duplicate the viewer when they are selected" do
    repository = repo_with_assignees("alice", "current_user")
    stub_viewer_login("current_user")

    get assignable_users_repository_url(repository), params: { selected: "current_user" }, as: :json

    json = JSON.parse(response.body)
    assert_equal 1, json.count { |u| u["login"] == "current_user" }
    assert_equal "current_user", json.first["login"]
  end

  test "should not pin the viewer when they do not match the query" do
    repository = repo_with_assignees("alice", "current_user")
    stub_viewer_login("current_user")

    get assignable_users_repository_url(repository), params: { q: "ali" }, as: :json

    assert_equal [ "alice" ], JSON.parse(response.body).map { |u| u["login"] }
  end

  # Never block a request on a full sync; search tops up from the API instead.
  test "should sync in the background when nothing has been synced yet" do
    repository = @user.repositories.create!(
      github_domain: "github.com", owner: "rails", name: "rails",
      full_name: "rails/rails", cached_at: 1.minute.ago
    )
    stub_no_viewer
    SyncRepositoryAssignableUsersJob.expects(:perform_now).never
    SyncRepositoryAssignableUsersJob.expects(:perform_later).with(repository.id).once

    get assignable_users_repository_url(repository), as: :json

    assert_response :success
  end

  test "should refresh a stale list in the background" do
    repository = repo_with_assignees("alice", synced_at: 2.days.ago)
    stub_no_viewer
    SyncRepositoryAssignableUsersJob.expects(:perform_later).with(repository.id).once

    get assignable_users_repository_url(repository), as: :json

    assert_response :success
    assert_equal [ "alice" ], JSON.parse(response.body).map { |u| u["login"] }
  end

  test "should not resync a fresh list" do
    repository = repo_with_assignees("alice")
    stub_no_viewer
    SyncRepositoryAssignableUsersJob.expects(:perform_now).never
    SyncRepositoryAssignableUsersJob.expects(:perform_later).never

    get assignable_users_repository_url(repository), as: :json

    assert_response :success
  end

  # A failed sync must not take out the dropdown.
  test "should still serve stored users when the sync fails" do
    repository = repo_with_assignees("alice", synced_at: 2.days.ago)
    stub_no_viewer
    SyncRepositoryAssignableUsersJob.stubs(:perform_later).raises(StandardError, "boom")

    get assignable_users_repository_url(repository), as: :json

    assert_response :success
    assert_equal [ "alice" ], JSON.parse(response.body).map { |u| u["login"] }
  end

  test "should serve the stored list even without a token" do
    repository = repo_with_assignees("alice")
    stub_no_viewer

    get assignable_users_repository_url(repository), as: :json

    assert_response :success
    assert_equal [ "alice" ], JSON.parse(response.body).map { |u| u["login"] }
  end


  # Labels endpoint (filter dropdown data source)

  test "should return repository labels as JSON" do
    repository = create_repository
    stub_labels_client([
      OpenStruct.new(name: "bug", color: "d73a4a"),
      OpenStruct.new(name: "enhancement", color: "a2eeef")
    ])

    get labels_repository_url(repository), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 2, json.length
    assert_equal [ "bug", "enhancement" ], json.map { |label| label["name"] }
    assert_equal "d73a4a", json.first["color"]
  end

  test "should filter labels by query" do
    repository = create_repository
    stub_labels_client([
      OpenStruct.new(name: "bug", color: "d73a4a"),
      OpenStruct.new(name: "debt", color: "cccccc"),
      OpenStruct.new(name: "enhancement", color: "a2eeef")
    ])

    get labels_repository_url(repository), params: { q: "B" }, as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal [ "bug", "debt" ], json.map { |label| label["name"] }
  end

  test "should limit labels to 50 results" do
    repository = create_repository
    stub_labels_client(60.times.map { |i| OpenStruct.new(name: "label-#{i}", color: "ffffff") })

    get labels_repository_url(repository), as: :json

    assert_response :success
    assert_equal 50, JSON.parse(response.body).length
  end

  test "should return error when no github token exists for labels" do
    repository = @user.repositories.create!(
      github_domain: "va.ghe.com",
      owner: "software",
      name: "eert",
      full_name: "software/eert",
      cached_at: 1.minute.ago
    )

    get labels_repository_url(repository), as: :json

    assert_response :unauthorized
    assert_includes JSON.parse(response.body)["error"], "No GitHub token found for va.ghe.com"
  end

  test "should handle label API errors gracefully" do
    repository = create_repository
    mock_api_client = mock
    mock_api_client.stubs(:fetch_labels).raises(StandardError.new("API Error"))
    Github::ApiClient.stubs(:new).returns(mock_api_client)

    get labels_repository_url(repository), as: :json

    assert_response :internal_server_error
    assert_includes JSON.parse(response.body)["error"], "Failed to fetch labels"
  end

  # GitHub lands you on Code, not Issues; the tabs cover the rest.
  test "index links a repository to its file browser" do
    repository = @user.repositories.create!(
      github_domain: "github.com", owner: "rails", name: "rails", full_name: "rails/rails"
    )

    get repositories_path

    assert_select "a[href=?]", repository_tree_path(repository), text: /rails\/rails/
  end

  private

  private

  def create_repository
    @user.repositories.create!(
      github_domain: "github.com",
      owner: "rails",
      name: "rails",
      full_name: "rails/rails",
      cached_at: 1.minute.ago
    )
  end

  def stub_labels_client(labels)
    mock_api_client = mock
    mock_api_client.stubs(:fetch_labels).returns(labels)
    Github::ApiClient.stubs(:new).returns(mock_api_client)
  end

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  # The synced list is only as complete as the sync got, so a short local
  # result set falls back to GitHub's own matching.
  test "should top up a thin local search from the API" do
    repository = repo_with_assignees("alice")
    # Only a truncated sync warrants the extra round-trip.
    Github::AssignableUserSearch.any_instance.stubs(:complete?).returns(false)
    @user.github_tokens.find_or_create_by!(domain: "github.com") { |t| t.token = "ghp_test_token" }
    Rails.cache.clear
    mock_client = mock
    mock_client.stubs(:user).returns(OpenStruct.new(login: "nobody", avatar_url: nil))
    api = mock
    api.stubs(:client).returns(mock_client)
    api.expects(:search_assignable_users)
      .with("rails", "rails", "zed", limit: 20)
      .returns([ { login: "zed", avatar_url: "https://example.com/zed.png" } ])
    Github::ApiClient.stubs(:new).returns(api)

    get assignable_users_repository_url(repository), params: { q: "zed" }, as: :json

    assert_equal [ "zed" ], JSON.parse(response.body).map { |u| u["login"] }
  end

  test "should not hit the API when the local search is already full" do
    repository = repo_with_assignees(*20.times.map { |i| "dev#{i.to_s.rjust(2, '0')}" })
    stub_no_viewer
    Github::ApiClient.expects(:new).never

    get assignable_users_repository_url(repository), params: { q: "dev" }, as: :json

    assert_equal 20, JSON.parse(response.body).length
  end

  # An ordinary repo's synced list is everyone, so a narrow match is not a
  # reason to ask GitHub again.
  test "should not hit the API when the synced list is already complete" do
    repository = repo_with_assignees("alice", "bob")
    stub_no_viewer
    Github::ApiClient.expects(:new).never

    get assignable_users_repository_url(repository), params: { q: "ali" }, as: :json

    assert_equal [ "alice" ], JSON.parse(response.body).map { |u| u["login"] }
  end

  test "should not hit the API when there is no query" do
    repository = repo_with_assignees("alice")
    stub_no_viewer
    Github::ApiClient.expects(:new).never

    get assignable_users_repository_url(repository), as: :json

    assert_equal [ "alice" ], JSON.parse(response.body).map { |u| u["login"] }
  end

  test "should fall back to local results when the API search fails" do
    repository = repo_with_assignees("alice")
    stub_no_viewer
    Github::AssignableUserSearch.any_instance.stubs(:complete?).returns(false)

    get assignable_users_repository_url(repository), params: { q: "ali" }, as: :json

    assert_response :success
    assert_equal [ "alice" ], JSON.parse(response.body).map { |u| u["login"] }
  end
end
