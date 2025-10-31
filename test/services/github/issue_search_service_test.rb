# frozen_string_literal: true

require "test_helper"

module Github
  class IssueSearchServiceTest < ActiveSupport::TestCase
    setup do
      @user = User.create!(email_address: "test@example.com", password: "password123")
      @repository = Repository.create!(
        user: @user,
        owner: "octocat",
        name: "hello-world",
        full_name: "octocat/hello-world",
        description: "Test repository",
        url: "https://github.com/octocat/hello-world",
        github_domain: "github.com"
      )

      # Create test issues
      @issue1 = Issue.create!(
        repository: @repository,
        number: 1,
        title: "Bug in login form",
        state: "open",
        body: "The login form has a validation error",
        author_login: "user1",
        author_avatar_url: "https://github.com/user1.png",
        labels: [ { "name" => "bug", "color" => "d73a4a" } ],
        assignees: [ { "login" => "dev1", "avatar_url" => "https://github.com/dev1.png" } ],
        comments_count: 5,
        github_created_at: 3.days.ago,
        github_updated_at: 1.day.ago,
        cached_at: Time.current
      )

      @issue2 = Issue.create!(
        repository: @repository,
        number: 2,
        title: "Add feature: dark mode",
        state: "open",
        body: "Users want dark mode support",
        author_login: "user2",
        author_avatar_url: "https://github.com/user2.png",
        labels: [ { "name" => "enhancement", "color" => "a2eeef" } ],
        assignees: [ { "login" => "dev2", "avatar_url" => "https://github.com/dev2.png" } ],
        comments_count: 10,
        github_created_at: 2.days.ago,
        github_updated_at: 2.hours.ago,
        cached_at: Time.current
      )

      @issue3 = Issue.create!(
        repository: @repository,
        number: 3,
        title: "Documentation update",
        state: "closed",
        body: "Update README with installation instructions",
        author_login: "user3",
        author_avatar_url: "https://github.com/user3.png",
        labels: [ { "name" => "documentation", "color" => "0075ca" } ],
        assignees: [],
        comments_count: 2,
        github_created_at: 5.days.ago,
        github_updated_at: 3.days.ago,
        cached_at: Time.current
      )
    end

    # Local search tests

    test "local search returns all issues when no query or filters" do
      service = IssueSearchService.new(user: @user, repository: @repository)
      result = service.call

      assert result[:success]
      assert_equal :local, result[:mode]
      assert_equal 3, result[:count]
      assert_includes result[:issues], @issue1
      assert_includes result[:issues], @issue2
      assert_includes result[:issues], @issue3
    end

    test "local search filters by text query in title" do
      service = IssueSearchService.new(
        user: @user,
        repository: @repository,
        query: "login"
      )
      result = service.call

      assert result[:success]
      assert_equal 1, result[:count]
      assert_includes result[:issues], @issue1
    end

    test "local search filters by text query in body" do
      service = IssueSearchService.new(
        user: @user,
        repository: @repository,
        query: "validation"
      )
      result = service.call

      assert result[:success]
      assert_equal 1, result[:count]
      assert_includes result[:issues], @issue1
    end

    test "local search filters by state open" do
      service = IssueSearchService.new(
        user: @user,
        repository: @repository,
        filters: { state: "open" }
      )
      result = service.call

      assert result[:success]
      assert_equal 2, result[:count]
      assert_includes result[:issues], @issue1
      assert_includes result[:issues], @issue2
      refute_includes result[:issues], @issue3
    end

    test "local search filters by state closed" do
      service = IssueSearchService.new(
        user: @user,
        repository: @repository,
        filters: { state: "closed" }
      )
      result = service.call

      assert result[:success]
      assert_equal 1, result[:count]
      assert_includes result[:issues], @issue3
    end

    test "local search filters by label" do
      service = IssueSearchService.new(
        user: @user,
        repository: @repository,
        filters: { labels: [ "bug" ] }
      )
      result = service.call

      assert result[:success]
      assert_equal 1, result[:count]
      assert_includes result[:issues], @issue1
    end

    test "local search filters by assignee" do
      service = IssueSearchService.new(
        user: @user,
        repository: @repository,
        filters: { assignee: "dev1" }
      )
      result = service.call

      assert result[:success]
      assert_equal 1, result[:count]
      assert_includes result[:issues], @issue1
    end

    test "local search combines query and filters" do
      service = IssueSearchService.new(
        user: @user,
        repository: @repository,
        query: "feature",
        filters: { state: "open", labels: [ "enhancement" ] }
      )
      result = service.call

      assert result[:success]
      assert_equal 1, result[:count]
      assert_includes result[:issues], @issue2
    end

    test "local search sorts by created date descending" do
      service = IssueSearchService.new(
        user: @user,
        repository: @repository,
        sort_by: "created"
      )
      result = service.call

      assert result[:success]
      issues = result[:issues].to_a
      assert_equal @issue2, issues[0]  # Most recent
      assert_equal @issue1, issues[1]
      assert_equal @issue3, issues[2]  # Oldest
    end

    test "local search sorts by updated date descending by default" do
      service = IssueSearchService.new(user: @user, repository: @repository)
      result = service.call

      assert result[:success]
      issues = result[:issues].to_a
      assert_equal @issue2, issues[0]  # Most recently updated
      assert_equal @issue1, issues[1]
      assert_equal @issue3, issues[2]
    end

    test "local search sorts by comments count descending" do
      service = IssueSearchService.new(
        user: @user,
        repository: @repository,
        sort_by: "comments"
      )
      result = service.call

      assert result[:success]
      issues = result[:issues].to_a
      assert_equal @issue2, issues[0]  # 10 comments
      assert_equal @issue1, issues[1]  # 5 comments
      assert_equal @issue3, issues[2]  # 2 comments
    end

    test "local search returns empty when no matches" do
      service = IssueSearchService.new(
        user: @user,
        repository: @repository,
        query: "nonexistent"
      )
      result = service.call

      assert result[:success]
      assert_equal 0, result[:count]
      assert_empty result[:issues]
    end

    # GitHub search mode tests

    test "github search mode returns error when no token configured" do
      service = IssueSearchService.new(
        user: @user,
        repository: @repository,
        query: "bug",
        search_mode: :github
      )
      result = service.call

      refute result[:success]
      assert_includes result[:error], "No GitHub token configured"
    end

    test "github search mode searches via API and syncs results" do
      github_token = @user.github_tokens.create!(
        token: "ghp_test_token",
        domain: "github.com"
      )

      mock_client = mock("ApiClient")
      mock_client.expects(:search_issues).with("repo:octocat/hello-world bug", sort: "created", order: "desc").returns([
        {
          number: 4,
          title: "New bug found",
          state: "open",
          body: "Description of bug",
          author_login: "user4",
          author_avatar_url: "https://github.com/user4.png",
          labels: [ { "name" => "bug", "color" => "d73a4a" } ],
          assignees: [],
          comments_count: 0,
          created_at: 1.day.ago,
          updated_at: 1.day.ago
        }
      ])
      mock_client.expects(:rate_limit_info).returns(nil)

      Github::ApiClient.expects(:new).with(
        token: github_token.token,
        domain: "github.com"
      ).returns(mock_client)

      service = IssueSearchService.new(
        user: @user,
        repository: @repository,
        query: "bug",
        search_mode: :github
      )
      result = service.call

      assert result[:success]
      assert_equal :github, result[:mode]
      assert_equal 1, result[:count]

      # Verify issue was synced to database
      synced_issue = @repository.issues.find_by(number: 4)
      assert_not_nil synced_issue
      assert_equal "New bug found", synced_issue.title
    end

    test "github search builds query with filters" do
      github_token = @user.github_tokens.create!(
        token: "ghp_test_token",
        domain: "github.com"
      )

      mock_client = mock("ApiClient")
      expected_query = "repo:octocat/hello-world search term state:open label:\"bug\" assignee:dev1"
      mock_client.expects(:search_issues).with(expected_query, sort: "created", order: "desc").returns([])
      mock_client.expects(:rate_limit_info).returns(nil)

      Github::ApiClient.expects(:new).returns(mock_client)

      service = IssueSearchService.new(
        user: @user,
        repository: @repository,
        query: "search term",
        filters: { state: "open", labels: [ "bug" ], assignee: "dev1" },
        search_mode: :github
      )
      result = service.call

      assert result[:success]
    end

    test "github search handles API errors" do
      github_token = @user.github_tokens.create!(
        token: "ghp_test_token",
        domain: "github.com"
      )

      mock_client = mock("ApiClient")
      mock_client.expects(:search_issues).returns({ error: "API error" })

      Github::ApiClient.expects(:new).returns(mock_client)

      service = IssueSearchService.new(
        user: @user,
        repository: @repository,
        query: "bug",
        search_mode: :github
      )
      result = service.call

      refute result[:success]
      assert_equal "API error", result[:error]
    end

    test "github search handles rate limit errors" do
      github_token = @user.github_tokens.create!(
        token: "ghp_test_token",
        domain: "github.com"
      )

      mock_client = mock("ApiClient")
      rate_limit_error = Octokit::TooManyRequests.new

      # Create a proper response_headers object
      def rate_limit_error.response_headers
        { "x-ratelimit-reset" => 1.hour.from_now.to_i.to_s }
      end

      mock_client.expects(:search_issues).raises(rate_limit_error)

      Github::ApiClient.expects(:new).returns(mock_client)

      service = IssueSearchService.new(
        user: @user,
        repository: @repository,
        query: "bug",
        search_mode: :github
      )
      result = service.call

      refute result[:success]
      assert_includes result[:error], "rate limit"
    end

    test "github search handles unauthorized errors" do
      github_token = @user.github_tokens.create!(
        token: "ghp_invalid_token",
        domain: "github.com"
      )

      mock_client = mock("ApiClient")
      mock_client.expects(:search_issues).raises(Octokit::Unauthorized)

      Github::ApiClient.expects(:new).returns(mock_client)

      service = IssueSearchService.new(
        user: @user,
        repository: @repository,
        query: "bug",
        search_mode: :github
      )
      result = service.call

      refute result[:success]
      assert_includes result[:error], "Unauthorized"
    end

    test "github search handles general errors" do
      github_token = @user.github_tokens.create!(
        token: "ghp_test_token",
        domain: "github.com"
      )

      mock_client = mock("ApiClient")
      mock_client.expects(:search_issues).raises(StandardError.new("Network error"))

      Github::ApiClient.expects(:new).returns(mock_client)

      service = IssueSearchService.new(
        user: @user,
        repository: @repository,
        query: "bug",
        search_mode: :github
      )
      result = service.call

      refute result[:success]
      assert_includes result[:error], "Search failed"
    end

    test "returns error for invalid search mode" do
      service = IssueSearchService.new(
        user: @user,
        repository: @repository,
        search_mode: :invalid
      )
      result = service.call

      refute result[:success]
      assert_includes result[:error], "Invalid search mode"
    end

    test "should sort by comments when sort_by is comments" do
      service = IssueSearchService.new(
        user: @user,
        repository: @repository,
        sort_by: "comments",
        search_mode: :local
      )
      result = service.call

      assert result[:success]
      # issue2 has 10 comments, issue1 has 5 comments
      assert_equal 2, result[:issues].first.number
    end

    test "should handle blank sort_by parameter" do
      service = IssueSearchService.new(
        user: @user,
        repository: @repository,
        sort_by: "",
        search_mode: :local
      )
      result = service.call

      assert result[:success]
      # Should still return all issues
      assert result[:issues].length >= 2
    end

    test "should parse sort with direction separator" do
      service = IssueSearchService.new(
        user: @user,
        repository: @repository,
        sort_by: "created-asc",
        search_mode: :local
      )
      result = service.call

      assert result[:success]
      # Should return issues in some order
      assert result[:issues].any?
    end

    test "should handle rate limit error without rate limit headers" do
      @user.github_tokens.create!(domain: "github.com", token: "test_token")

      mock_client = mock("ApiClient")
      mock_error = Octokit::TooManyRequests.new(
        response_headers: {}
      )
      mock_client.expects(:search_issues).raises(mock_error)

      Github::ApiClient.expects(:new).returns(mock_client)

      service = IssueSearchService.new(
        user: @user,
        repository: @repository,
        query: "test",
        search_mode: :github
      )
      result = service.call

      refute result[:success]
      assert_includes result[:error], "rate limit"
      assert_nil result[:rate_limit]
    end
  end
end
