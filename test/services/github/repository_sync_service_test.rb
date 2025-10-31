require "test_helper"

# Tests for GitHub RepositorySyncService with mocked API calls
class Github::RepositorySyncServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    # Clear any existing repositories to avoid conflicts
    @user.repositories.destroy_all
    @github_token = @user.github_tokens.create!(
      domain: "github.com",
      token: "test_token_123"
    )
    @service = Github::RepositorySyncService.new(
      user: @user,
      github_domain: "github.com",
      owner: "rails",
      repo_name: "rails"
    )
  end

  # Successful sync tests

  test "should successfully sync repository data" do
    mock_client = create_mock_client_with_repo_data

    Github::ApiClient.stubs(:new).returns(mock_client)

    result = @service.call

    assert result[:success]
    assert_not_nil result[:repository]

    # Verify repository was created/updated
    repo = @user.repositories.find_by(owner: "rails", name: "rails")
    assert_not_nil repo
    assert_equal "rails/rails", repo.full_name
    assert_equal "Ruby on Rails", repo.description
    assert_equal "https://github.com/rails/rails", repo.url
    assert_equal 0, repo.issue_count  # Not provided by API
    assert_equal 100, repo.open_issue_count
    assert repo.cached_at >= 1.second.ago
  end

  test "should update existing repository on re-sync" do
    # Create initial repository
    existing_repo = @user.repositories.create!(
      github_domain: "github.com",
      owner: "rails",
      name: "rails",
      full_name: "rails/rails",
      description: "Old description",
      url: "https://github.com/rails/rails",
      open_issue_count: 50
    )

    mock_client = create_mock_client_with_repo_data
    Github::ApiClient.stubs(:new).returns(mock_client)

    result = @service.call

    assert result[:success]

    # Verify repository was updated, not duplicated
    assert_equal 1, @user.repositories.where(owner: "rails", name: "rails").count
    repo = existing_repo.reload
    assert_equal "Ruby on Rails", repo.description  # Updated
    assert_equal 100, repo.open_issue_count  # Updated
  end

  test "should handle nil issue counts gracefully" do
    mock_client = Object.new
    mock_client.define_singleton_method(:fetch_repository) do |_owner, _repo_name|
      {
        owner: "rails",
        name: "rails",
        full_name: "rails/rails",
        description: "Ruby on Rails",
        url: "https://github.com/rails/rails",
        open_issues_count: nil  # Nil count
      }
    end

    Github::ApiClient.stubs(:new).returns(mock_client)

    result = @service.call

    assert result[:success]
    repo = result[:repository]
    assert_equal 0, repo.issue_count
    assert_equal 0, repo.open_issue_count
  end

  # Error handling tests

  test "should return error when github token is missing" do
    @github_token.destroy

    result = @service.call

    assert_not result[:success]
    assert_includes result[:error], "No GitHub token configured"
  end

  test "should handle repository not found error" do
    mock_client = Object.new
    mock_client.define_singleton_method(:fetch_repository) do |_owner, _repo_name|
      { error: "Repository not found" }
    end

    Github::ApiClient.stubs(:new).returns(mock_client)

    result = @service.call

    assert_not result[:success]
    assert_equal "Repository not found", result[:error]
  end

  test "should handle unauthorized error" do
    mock_client = Object.new
    mock_client.define_singleton_method(:fetch_repository) do |_owner, _repo_name|
      { error: "Unauthorized - check your GitHub token" }
    end

    Github::ApiClient.stubs(:new).returns(mock_client)

    result = @service.call

    assert_not result[:success]
    assert_includes result[:error], "Unauthorized"
  end

  # Test helper methods

  def create_mock_client_with_repo_data
    mock_client = Object.new
    mock_client.define_singleton_method(:fetch_repository) do |_owner, _repo_name|
      {
        owner: "rails",
        name: "rails",
        full_name: "rails/rails",
        description: "Ruby on Rails",
        url: "https://github.com/rails/rails",
        open_issues_count: 100
      }
    end
    mock_client
  end
end
