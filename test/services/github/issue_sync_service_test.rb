require "test_helper"

# Tests for GitHub IssueSyncService with mocked API calls
class Github::IssueSyncServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @repository = repositories(:one)
    # Clear any existing issues from fixtures to avoid conflicts
    @repository.issues.destroy_all
    @github_token = @user.github_tokens.create!(
      domain: "github.com",
      token: "test_token_123"
    )
    @service = Github::IssueSyncService.new(user: @user, repository: @repository)
  end

  # Successful sync tests

  test "should successfully sync issues and comments" do
    mock_client = create_mock_client_with_issues_and_comments

    Github::ApiClient.stubs(:new).returns(mock_client)

    result = @service.call

    assert result[:success]
    assert_equal 2, result[:synced_count]

    # Verify issues were created
    assert_equal 2, @repository.issues.count

    # Verify first issue
    issue1 = @repository.issues.find_by(number: 1)
    assert_not_nil issue1
    assert_equal "Test Issue 1", issue1.title
    assert_equal "open", issue1.state
    assert_equal "Issue body 1", issue1.body
    assert_equal "octocat", issue1.author_login
    assert_equal [ { "name" => "bug", "color" => "d73a4a" } ], issue1.labels
    assert_equal 2, issue1.comments_count

    # Verify comments were created
    assert_equal 2, issue1.issue_comments.count
    comment1 = issue1.issue_comments.first
    assert_equal 123456, comment1.github_id
    assert_equal "commenter1", comment1.author_login
    assert_equal "This is a comment", comment1.body

    # Verify repository cached_at was updated
    assert @repository.reload.cached_at >= 1.second.ago
  end

  test "should update existing issues on re-sync" do
    # Create initial issue
    @repository.issues.create!(
      number: 1,
      title: "Old Title",
      state: "open",
      body: "Old body",
      author_login: "olduser"
    )

    mock_client = create_mock_client_with_issues_and_comments
    Github::ApiClient.stubs(:new).returns(mock_client)

    result = @service.call

    assert result[:success]

    # Verify issue was updated, not duplicated
    assert_equal 2, @repository.issues.count
    issue1 = @repository.issues.find_by(number: 1)
    assert_equal "Test Issue 1", issue1.title  # Updated
  end

  test "should update existing comments on re-sync" do
    issue = @repository.issues.create!(
      number: 1,
      title: "Test",
      state: "open"
    )

    issue.issue_comments.create!(
      github_id: 123456,
      author_login: "olduser",
      body: "Old comment"
    )

    mock_client = create_mock_client_with_issues_and_comments
    Github::ApiClient.stubs(:new).returns(mock_client)

    result = @service.call

    assert result[:success]

    # Verify comment was updated
    comment = issue.reload.issue_comments.find_by(github_id: 123456)
    assert_equal "commenter1", comment.author_login  # Updated
  end

  test "should handle issues without comments" do
    mock_client = create_mock_client_with_issues_no_comments
    Github::ApiClient.stubs(:new).returns(mock_client)

    result = @service.call

    assert result[:success]
    assert_equal 1, result[:synced_count]

    issue = @repository.issues.find_by(number: 1)
    assert_equal 0, issue.issue_comments.count
  end

  # Single issue sync tests

  test "should successfully sync a single issue by number" do
    service = Github::IssueSyncService.new(user: @user, repository: @repository, issue_number: 42)
    mock_client = create_mock_client_with_single_issue(42)

    Github::ApiClient.stubs(:new).returns(mock_client)

    result = service.call

    assert result[:success]
    assert_equal 1, result[:synced_count]

    # Verify only the requested issue was created
    assert_equal 1, @repository.issues.count
    issue = @repository.issues.find_by(number: 42)
    assert_not_nil issue
    assert_equal "Test Issue 42", issue.title
    assert_equal "open", issue.state
  end

  test "should handle API error when fetching single issue" do
    service = Github::IssueSyncService.new(user: @user, repository: @repository, issue_number: 99)
    mock_client = Object.new
    mock_client.define_singleton_method(:fetch_issue) do |_owner, _repo_name, _issue_number|
      { error: "Issue not found" }
    end

    Github::ApiClient.stubs(:new).returns(mock_client)

    result = service.call

    assert_not result[:success]
    assert_equal "Issue not found", result[:error]
    assert result[:cache_preserved]
  end

  test "should update existing single issue on re-sync" do
    # Create initial issue
    @repository.issues.create!(
      number: 42,
      title: "Old Title",
      state: "open",
      body: "Old body",
      author_login: "olduser"
    )

    service = Github::IssueSyncService.new(user: @user, repository: @repository, issue_number: 42)
    mock_client = create_mock_client_with_single_issue(42)
    Github::ApiClient.stubs(:new).returns(mock_client)

    result = service.call

    assert result[:success]
    assert_equal 1, result[:synced_count]

    # Verify issue was updated, not duplicated
    assert_equal 1, @repository.issues.count
    issue = @repository.issues.find_by(number: 42)
    assert_equal "Test Issue 42", issue.title  # Updated
  end

  # Error handling tests

  test "should return error when github token is missing" do
    @github_token.destroy

    result = @service.call

    assert_not result[:success]
    assert_includes result[:error], "No GitHub token configured"
  end

  test "should handle API error and preserve cache" do
    mock_client = Object.new
    mock_client.define_singleton_method(:fetch_issues) do |_owner, _repo_name, state:|
      { error: "Repository not found" }
    end

    Github::ApiClient.stubs(:new).returns(mock_client)

    result = @service.call

    assert_not result[:success]
    assert_equal "Repository not found", result[:error]
    assert result[:cache_preserved]
  end

  test "should handle rate limit error and preserve cache" do
    mock_client = Object.new
    mock_client.define_singleton_method(:fetch_issues) do |_owner, _repo_name, state:|
      error = Octokit::TooManyRequests.new
      def error.response_headers
        { "x-ratelimit-reset" => (Time.now + 3600).to_i.to_s }
      end
      raise error
    end

    Github::ApiClient.stubs(:new).returns(mock_client)

    result = @service.call

    assert_not result[:success]
    assert_includes result[:error], "Rate limit exceeded"
    assert result[:cache_preserved]
  end

  test "should handle unauthorized error and preserve cache" do
    mock_client = Object.new
    mock_client.define_singleton_method(:fetch_issues) do |_owner, _repo_name, state:|
      raise Octokit::Unauthorized.new
    end

    Github::ApiClient.stubs(:new).returns(mock_client)

    result = @service.call

    assert_not result[:success]
    assert_includes result[:error], "Unauthorized"
    assert result[:cache_preserved]
  end

  test "should handle general errors and preserve cache" do
    mock_client = Object.new
    mock_client.define_singleton_method(:fetch_issues) do |_owner, _repo_name, state:|
      raise StandardError.new("Unexpected error")
    end

    Github::ApiClient.stubs(:new).returns(mock_client)

    result = @service.call

    assert_not result[:success]
    assert_includes result[:error], "Failed to sync issues"
    assert result[:cache_preserved]
  end

  # Transaction tests

  test "should rollback all changes if error occurs mid-sync" do
    test_context = self
    mock_client = Object.new
    call_count = 0
    mock_client.define_singleton_method(:fetch_issues) do |_owner, _repo_name, state:|
      [ test_context.sample_issue_data(1), test_context.sample_issue_data(2) ]
    end
    mock_client.define_singleton_method(:fetch_issue_comments) do |_owner, _repo_name, issue_number|
      call_count += 1
      # First call succeeds, second call raises error
      if call_count == 1
        test_context.sample_comments_data
      else
        raise StandardError.new("Comment fetch failed")
      end
    end

    Github::ApiClient.stubs(:new).returns(mock_client)

    result = @service.call

    assert_not result[:success]

    # Verify transaction rolled back - no issues should be saved
    assert_equal 0, @repository.issues.count
  end

  # Test helper methods

  def create_mock_client_with_issues_and_comments
    test_context = self
    mock_client = Object.new
    mock_client.define_singleton_method(:fetch_issues) do |_owner, _repo_name, state:|
      [ test_context.sample_issue_data(1), test_context.sample_issue_data(2) ]
    end
    mock_client.define_singleton_method(:fetch_issue_comments) do |_owner, _repo_name, issue_number|
      issue_number == 1 ? test_context.sample_comments_data : []
    end
    mock_client
  end

  def create_mock_client_with_issues_no_comments
    test_context = self
    mock_client = Object.new
    mock_client.define_singleton_method(:fetch_issues) do |_owner, _repo_name, state:|
      [ test_context.sample_issue_data(1) ]
    end
    mock_client.define_singleton_method(:fetch_issue_comments) do |_owner, _repo_name, _issue_number|
      []
    end
    mock_client
  end

  def create_mock_client_with_single_issue(issue_number)
    test_context = self
    mock_client = Object.new
    mock_client.define_singleton_method(:fetch_issue) do |_owner, _repo_name, _issue_number|
      test_context.sample_issue_data(_issue_number)
    end
    mock_client.define_singleton_method(:fetch_issue_comments) do |_owner, _repo_name, _issue_number|
      []
    end
    mock_client
  end

  def sample_issue_data(number)
    {
      number: number,
      title: "Test Issue #{number}",
      state: "open",
      body: "Issue body #{number}",
      author_login: "octocat",
      author_avatar_url: "https://github.com/images/octocat.png",
      labels: [ { name: "bug", color: "d73a4a" } ],
      assignees: [ { login: "assignee1", avatar_url: "https://github.com/images/user.png" } ],
      comments_count: number == 1 ? 2 : 0,
      created_at: 1.day.ago,
      updated_at: 1.hour.ago
    }
  end

  def sample_comments_data
    [
      {
        github_id: 123456,
        author_login: "commenter1",
        author_avatar_url: "https://github.com/images/commenter1.png",
        body: "This is a comment",
        created_at: 1.day.ago,
        updated_at: 1.day.ago
      },
      {
        github_id: 123457,
        author_login: "commenter2",
        author_avatar_url: "https://github.com/images/commenter2.png",
        body: "Another comment",
        created_at: 1.hour.ago,
        updated_at: 1.hour.ago
      }
    ]
  end
end
