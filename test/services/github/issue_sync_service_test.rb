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

  test "should successfully sync issues" do
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

    # Verify repository cached_at was updated
    assert @repository.reload.cached_at >= 1.second.ago
  end

  # Bulk sync must not make one comment request per issue - that turned list
  # pages into 200+ sequential API round-trips. Comments are fetched lazily by
  # the show page instead.
  test "should not prefetch comments during a bulk sync" do
    mock_client = create_mock_client_with_issues_and_comments
    comment_calls = []
    mock_client.define_singleton_method(:fetch_issue_comments) do |_owner, _repo_name, issue_number|
      comment_calls << issue_number
      []
    end

    Github::ApiClient.stubs(:new).returns(mock_client)

    result = @service.call

    assert result[:success]
    assert_empty comment_calls
    assert_equal 0, IssueComment.where(issue: @repository.issues).count
  end

  # A nil cached_at is the signal IssueShowable uses to fetch the full issue
  # (including comments) the first time it is viewed.
  test "should leave bulk synced issues uncached so the show page hydrates them" do
    mock_client = create_mock_client_with_issues_and_comments
    Github::ApiClient.stubs(:new).returns(mock_client)

    @service.call

    assert_nil @repository.issues.find_by(number: 1).cached_at
    assert_nil @repository.issues.find_by(number: 2).cached_at
  end

  test "should preserve cached_at of already hydrated issues on bulk re-sync" do
    hydrated_at = 2.minutes.ago
    @repository.issues.create!(
      number: 1,
      title: "Old Title",
      state: "open",
      cached_at: hydrated_at
    )

    mock_client = create_mock_client_with_issues_and_comments
    Github::ApiClient.stubs(:new).returns(mock_client)

    @service.call

    issue = @repository.issues.find_by(number: 1)
    assert_equal "Test Issue 1", issue.title
    assert_in_delta hydrated_at, issue.cached_at, 1.second
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

    # Comments are only synced for single-issue refreshes now
    service = Github::IssueSyncService.new(user: @user, repository: @repository, issue_number: 1)
    test_context = self
    mock_client = create_mock_client_with_single_issue(1)
    mock_client.define_singleton_method(:fetch_issue_comments) do |_owner, _repo_name, _issue_number|
      test_context.sample_comments_data
    end
    Github::ApiClient.stubs(:new).returns(mock_client)

    result = service.call

    assert result[:success]

    # Verify comment was updated
    comment = issue.reload.issue_comments.find_by(github_id: 123456)
    assert_equal "commenter1", comment.author_login  # Updated
  end

  # Regression: GitHub omits deleted comments from the list response rather
  # than flagging them, so a cached copy survives every re-sync unless we
  # prune ids that stopped coming back. The show page then keeps rendering
  # the deleted comment because the timeline API drops it too, and cached
  # comments missing from the timeline are treated as ones to add back.
  test "should delete cached comments that no longer exist on GitHub" do
    issue = @repository.issues.create!(number: 1, title: "Test", state: "open")

    issue.issue_comments.create!(github_id: 123456, author_login: "commenter1", body: "Kept")
    issue.issue_comments.create!(github_id: 999999, author_login: "ghost", body: "Deleted upstream")

    service = Github::IssueSyncService.new(user: @user, repository: @repository, issue_number: 1)
    test_context = self
    mock_client = create_mock_client_with_single_issue(1)
    mock_client.define_singleton_method(:fetch_issue_comments) do |_owner, _repo_name, _issue_number|
      test_context.sample_comments_data
    end
    Github::ApiClient.stubs(:new).returns(mock_client)

    assert service.call[:success]

    github_ids = issue.reload.issue_comments.pluck(:github_id)

    assert_not_includes github_ids, 999999
    assert_includes github_ids, 123456
  end

  # Deleting the *last* comment returns an empty array, which the old guard
  # treated as "nothing to do" and returned early on, stranding every
  # cached comment.
  test "should delete cached comments when GitHub returns none" do
    issue = @repository.issues.create!(number: 1, title: "Test", state: "open")
    issue.issue_comments.create!(github_id: 123456, author_login: "ghost", body: "Deleted upstream")

    service = Github::IssueSyncService.new(user: @user, repository: @repository, issue_number: 1)
    mock_client = create_mock_client_with_single_issue(1)
    mock_client.define_singleton_method(:fetch_issue_comments) do |_owner, _repo_name, _issue_number|
      []
    end
    Github::ApiClient.stubs(:new).returns(mock_client)

    assert service.call[:success]
    assert_equal 0, issue.reload.issue_comments.count
  end

  # An error payload means we learned nothing about the comment thread, so the
  # cache has to survive rather than be mistaken for an empty thread.
  test "should keep cached comments when the comments request errors" do
    issue = @repository.issues.create!(number: 1, title: "Test", state: "open")
    issue.issue_comments.create!(github_id: 123456, author_login: "commenter1", body: "Kept")

    service = Github::IssueSyncService.new(user: @user, repository: @repository, issue_number: 1)
    mock_client = create_mock_client_with_single_issue(1)
    mock_client.define_singleton_method(:fetch_issue_comments) do |_owner, _repo_name, _issue_number|
      { error: "rate limited" }
    end
    Github::ApiClient.stubs(:new).returns(mock_client)

    assert service.call[:success]
    assert_equal 1, issue.reload.issue_comments.count
  end

  # Regression for the interaction between the prune and a 404 comments
  # response: `fetch_issue_comments` used to rescue Octokit::NotFound into an
  # empty array, which the prune could not distinguish from a genuine empty
  # thread, so it destroyed every cached comment.
  test "should keep cached comments when the comments request 404s" do
    issue = @repository.issues.create!(number: 1, title: "Test", state: "open")
    issue.issue_comments.create!(github_id: 123456, author_login: "commenter1", body: "Kept")

    service = Github::IssueSyncService.new(user: @user, repository: @repository, issue_number: 1)
    mock_client = create_mock_client_with_single_issue(1)
    mock_client.define_singleton_method(:fetch_issue_comments) do |_owner, _repo_name, _issue_number|
      { error: Github::ApiClient::ERROR_ISSUE_NOT_FOUND }
    end
    Github::ApiClient.stubs(:new).returns(mock_client)

    assert service.call[:success]
    assert_equal 1, issue.reload.issue_comments.count
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
    mock_client.define_singleton_method(:fetch_issues) do |_owner, _repo_name, state:, max_issues: nil|
      { error: "Repository not found" }
    end

    Github::ApiClient.stubs(:new).returns(mock_client)

    result = @service.call

    assert_not result[:success]
    assert_equal "Repository not found", result[:error]
    assert result[:cache_preserved]
  end

  test "should handle Hash response without error key" do
    mock_client = Object.new
    mock_client.define_singleton_method(:fetch_issues) do |_owner, _repo_name, state:, max_issues: nil|
      # Return a Hash without :error key (or with error: nil)
      { some_other_key: "value" }
    end

    Github::ApiClient.stubs(:new).returns(mock_client)

    result = @service.call

    # Should continue past the error check since error is nil
    # and attempt to sync (which will fail because it's not an array)
    assert_not result[:success]
    assert_includes result[:error], "Failed to sync issues"
  end

  test "should handle rate limit error and preserve cache" do
    mock_client = Object.new
    mock_client.define_singleton_method(:fetch_issues) do |_owner, _repo_name, state:, max_issues: nil|
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
    mock_client.define_singleton_method(:fetch_issues) do |_owner, _repo_name, state:, max_issues: nil|
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
    mock_client.define_singleton_method(:fetch_issues) do |_owner, _repo_name, state:, max_issues: nil|
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
    mock_client.define_singleton_method(:fetch_issues) do |_owner, _repo_name, state:, max_issues: nil|
      # Second issue is invalid (no title), so save! raises part-way through
      [ test_context.sample_issue_data(1), test_context.sample_issue_data(2).merge(title: nil) ]
    end
    mock_client.define_singleton_method(:rate_limit_info) do
      nil
    end

    Github::ApiClient.stubs(:new).returns(mock_client)

    result = @service.call

    assert_not result[:success]

    # Verify transaction rolled back - no issues should be saved
    assert_equal 0, @repository.issues.count
  end

  # Pull request diff statistics

  test "should sync diff statistics for a single pull request" do
    service = Github::IssueSyncService.new(user: @user, repository: @repository, issue_number: 7)
    mock_client = create_mock_client_with_single_issue(7, pull_request: true)
    Github::ApiClient.stubs(:new).returns(mock_client)

    assert service.call[:success]

    pull = @repository.issues.find_by(number: 7)

    assert_equal 12, pull.commits_count
    assert_equal 3, pull.changed_files_count
    assert_equal 608, pull.additions
    assert_equal 42, pull.deletions
  end

  # The extra request only makes sense for pull requests; issues have no diff.
  test "should not call the pull request endpoint for a plain issue" do
    service = Github::IssueSyncService.new(user: @user, repository: @repository, issue_number: 7)
    mock_client = create_mock_client_with_single_issue(7)
    mock_client.define_singleton_method(:fetch_pull_request) do |*_args|
      raise "fetch_pull_request should not be called for an issue"
    end
    Github::ApiClient.stubs(:new).returns(mock_client)

    assert service.call[:success]
    assert_nil @repository.issues.find_by(number: 7).commits_count
  end

  # Stale counts on a tab beat blanking them out, so a failed stats fetch must
  # not clobber what we already had, nor fail the whole sync.
  test "should keep existing diff statistics when the pull request endpoint errors" do
    @repository.issues.create!(
      number: 7, title: "Existing", state: "open", pull_request: true, commits_count: 5, additions: 100
    )

    service = Github::IssueSyncService.new(user: @user, repository: @repository, issue_number: 7)
    mock_client = create_mock_client_with_single_issue(7, pull_request: true)
    mock_client.define_singleton_method(:fetch_pull_request) do |*_args|
      { error: "Rate limit exceeded" }
    end
    Github::ApiClient.stubs(:new).returns(mock_client)

    assert service.call[:success]

    pull = @repository.issues.find_by(number: 7)

    assert_equal 5, pull.commits_count
    assert_equal 100, pull.additions
  end

  # Bulk syncs already skip comments to stay fast; an extra request per pull
  # request would undo that.
  test "should not fetch diff statistics during a bulk sync" do
    service = Github::IssueSyncService.new(user: @user, repository: @repository)
    test_context = self
    mock_client = Object.new
    mock_client.define_singleton_method(:fetch_issues) do |_owner, _repo_name, state:, max_issues: nil|
      [ test_context.sample_issue_data(7).merge(pull_request: true) ]
    end
    mock_client.define_singleton_method(:rate_limit_info) { nil }
    mock_client.define_singleton_method(:fetch_pull_request) do |*_args|
      raise "fetch_pull_request should not be called during a bulk sync"
    end
    Github::ApiClient.stubs(:new).returns(mock_client)

    assert service.call[:success]
    assert_nil @repository.issues.find_by(number: 7).commits_count
  end

  # Test helper methods

  def create_mock_client_with_issues_and_comments
    test_context = self
    mock_client = Object.new
    mock_client.define_singleton_method(:fetch_issues) do |_owner, _repo_name, state:, max_issues: nil|
      [ test_context.sample_issue_data(1), test_context.sample_issue_data(2) ]
    end
    mock_client.define_singleton_method(:fetch_issue_comments) do |_owner, _repo_name, issue_number|
      issue_number == 1 ? test_context.sample_comments_data : []
    end
    mock_client.define_singleton_method(:rate_limit_info) do
      nil
    end
    mock_client
  end

  def create_mock_client_with_issues_no_comments
    test_context = self
    mock_client = Object.new
    mock_client.define_singleton_method(:fetch_issues) do |_owner, _repo_name, state:, max_issues: nil|
      [ test_context.sample_issue_data(1) ]
    end
    mock_client.define_singleton_method(:fetch_issue_comments) do |_owner, _repo_name, _issue_number|
      []
    end
    mock_client.define_singleton_method(:rate_limit_info) do
      nil
    end
    mock_client
  end

  def create_mock_client_with_single_issue(issue_number, pull_request: false)
    test_context = self
    mock_client = Object.new
    mock_client.define_singleton_method(:fetch_issue) do |_owner, _repo_name, _issue_number|
      test_context.sample_issue_data(_issue_number).merge(pull_request: pull_request)
    end
    mock_client.define_singleton_method(:fetch_issue_comments) do |_owner, _repo_name, _issue_number|
      []
    end
    mock_client.define_singleton_method(:fetch_pull_request) do |_owner, _repo_name, _issue_number|
      { commits_count: 12, changed_files_count: 3, additions: 608, deletions: 42 }
    end
    mock_client.define_singleton_method(:rate_limit_info) do
      nil
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
