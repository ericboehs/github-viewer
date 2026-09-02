require "test_helper"
require "ostruct"

class Github::ApiClientTest < ActiveSupport::TestCase
  setup do
    @token = "test_token_123"
    @domain = "github.com"
    @client = Github::ApiClient.new(token: @token, domain: @domain)
  end

  # Configuration and initialization tests

  test "should raise configuration error without token" do
    assert_raises Github::ApiClient::ConfigurationError do
      Github::ApiClient.new(token: nil, domain: @domain)
    end
  end

  test "should raise configuration error without domain" do
    assert_raises Github::ApiClient::ConfigurationError do
      Github::ApiClient.new(token: @token, domain: nil)
    end
  end

  test "should initialize with valid configuration" do
    assert_instance_of Github::ApiClient, @client
    assert_equal @token, @client.token
    assert_equal @domain, @client.domain
    assert_instance_of Octokit::Client, @client.client
  end

  test "should have correct default configuration" do
    assert_equal 0.1, Github::ApiClient.config.default_rate_limit_delay
    assert_equal 3, Github::ApiClient.config.max_retries
  end

  test "should configure GitHub Enterprise endpoint" do
    ghe_client = Github::ApiClient.new(token: @token, domain: "github.example.com")
    octokit_client = ghe_client.client

    assert_includes octokit_client.api_endpoint, "github.example.com"
  end

  test "should pass sort parameter to search" do
    mock_octokit_client = mock("OctokitClient")
    mock_results = OpenStruct.new(
      items: [
        OpenStruct.new(
          number: 1,
          title: "Test",
          state: "open",
          user: OpenStruct.new(login: "user"),
          created_at: Time.current,
          updated_at: Time.current,
          labels: [],
          assignees: []
        )
      ],
      total_count: 1
    )
    mock_response = OpenStruct.new(headers: {})

    # Mock all Octokit calls including auto_paginate
    mock_octokit_client.expects(:auto_paginate).returns(true)
    mock_octokit_client.expects(:auto_paginate=).with(false)
    mock_octokit_client.expects(:search_issues).with("test query", has_entry(:sort, "created")).returns(mock_results)
    mock_octokit_client.expects(:auto_paginate=).with(true)
    mock_octokit_client.stubs(:last_response).returns(mock_response)
    @client.instance_variable_set(:@client, mock_octokit_client)

    results = @client.search_issues("test query", sort: "created")
    assert_equal 1, results[:items].length
    assert_equal 1, results[:total_count]
  end

  test "should pass order parameter to search" do
    mock_octokit_client = mock("OctokitClient")
    mock_results = OpenStruct.new(
      items: [
        OpenStruct.new(
          number: 1,
          title: "Test",
          state: "open",
          user: OpenStruct.new(login: "user"),
          created_at: Time.current,
          updated_at: Time.current,
          labels: [],
          assignees: []
        )
      ],
      total_count: 1
    )
    mock_response = OpenStruct.new(headers: {})

    # Mock all Octokit calls including auto_paginate
    mock_octokit_client.expects(:auto_paginate).returns(true)
    mock_octokit_client.expects(:auto_paginate=).with(false)
    mock_octokit_client.expects(:search_issues).with("test query", has_entry(:order, "asc")).returns(mock_results)
    mock_octokit_client.expects(:auto_paginate=).with(true)
    mock_octokit_client.stubs(:last_response).returns(mock_response)
    @client.instance_variable_set(:@client, mock_octokit_client)

    results = @client.search_issues("test query", order: "asc")
    assert_equal 1, results[:items].length
    assert_equal 1, results[:total_count]
  end

  # Repository fetch tests

  test "should fetch repository successfully" do
    mock_repo = OpenStruct.new(
      owner: OpenStruct.new(login: "rails"),
      name: "rails",
      full_name: "rails/rails",
      description: "Ruby on Rails",
      html_url: "https://github.com/rails/rails",
      open_issues_count: 100
    )

    mock_client = OpenStruct.new
    def mock_client.repository(full_name)
      OpenStruct.new(
        owner: OpenStruct.new(login: "rails"),
        name: "rails",
        full_name: "rails/rails",
        description: "Ruby on Rails",
        html_url: "https://github.com/rails/rails",
        open_issues_count: 100
      )
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_repository("rails", "rails")

    assert_equal "rails", result[:owner]
    assert_equal "rails", result[:name]
    assert_equal "rails/rails", result[:full_name]
    assert_equal "Ruby on Rails", result[:description]
    assert_equal "https://github.com/rails/rails", result[:url]
    assert_equal 100, result[:open_issues_count]
  end

  test "should handle repository not found" do
    mock_client = OpenStruct.new
    def mock_client.repository(full_name)
      raise Octokit::NotFound.new
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_repository("nonexistent", "repo")

    assert result.is_a?(Hash)
    assert_equal "Repository not found", result[:error]
  end

  test "should handle unauthorized error" do
    mock_client = OpenStruct.new
    def mock_client.repository(full_name)
      raise Octokit::Unauthorized.new
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_repository("rails", "rails")

    assert result.is_a?(Hash)
    assert_equal "Unauthorized - check your GitHub token", result[:error]
  end

  test "should handle SAML protected error" do
    mock_client = OpenStruct.new
    def mock_client.repository(full_name)
      raise Octokit::SAMLProtected.new
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_repository("rails", "rails")

    assert result.is_a?(Hash)
    assert_includes result[:error], "SAML SSO authorization"
    assert_includes result[:error], "https://docs.github.com"
  end

  # Issue fetch tests

  test "should fetch issues successfully" do
    mock_issues = [
      OpenStruct.new(
        number: 1,
        title: "Issue 1",
        state: "open",
        body: "Body 1",
        user: OpenStruct.new(login: "user1", avatar_url: "https://avatar1.png"),
        labels: [ OpenStruct.new(name: "bug", color: "d73a4a") ],
        assignees: [ OpenStruct.new(login: "assignee1", avatar_url: "https://avatar2.png") ],
        comments: 5,
        created_at: 1.day.ago,
        updated_at: 1.hour.ago
      )
    ]

    mock_client = OpenStruct.new
    def mock_client.issues(repo, options)
      [
        OpenStruct.new(
          number: 1,
          title: "Issue 1",
          state: "open",
          body: "Body 1",
          user: OpenStruct.new(login: "user1", avatar_url: "https://avatar1.png"),
          labels: [ OpenStruct.new(name: "bug", color: "d73a4a") ],
          assignees: [ OpenStruct.new(login: "assignee1", avatar_url: "https://avatar2.png") ],
          comments: 5,
          created_at: 1.day.ago,
          updated_at: 1.hour.ago
        )
      ]
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_issues("rails", "rails", state: "all")

    assert_equal 1, result.length
    assert_equal 1, result.first[:number]
    assert_equal "Issue 1", result.first[:title]
    assert_equal "open", result.first[:state]
    assert_equal "user1", result.first[:author_login]
    assert_equal 1, result.first[:labels].length
    assert_equal "bug", result.first[:labels].first[:name]
  end

  test "should handle SAML protected error in fetch_issues" do
    mock_client = OpenStruct.new
    def mock_client.issues(repo, options)
      raise Octokit::SAMLProtected.new
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_issues("rails", "rails", state: "all")

    assert result.is_a?(Hash)
    assert_includes result[:error], "SAML SSO authorization"
    assert_includes result[:error], "https://docs.github.com"
  end

  # Comment fetch tests

  test "should fetch issue comments successfully" do
    mock_comments = [
      OpenStruct.new(
        id: 123,
        user: OpenStruct.new(login: "commenter1", avatar_url: "https://avatar3.png"),
        body: "Comment body",
        created_at: 1.hour.ago,
        updated_at: 1.hour.ago
      )
    ]

    mock_client = OpenStruct.new
    def mock_client.issue_comments(repo, issue_number)
      [
        OpenStruct.new(
          id: 123,
          user: OpenStruct.new(login: "commenter1", avatar_url: "https://avatar3.png"),
          body: "Comment body",
          created_at: 1.hour.ago,
          updated_at: 1.hour.ago
        )
      ]
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_issue_comments("rails", "rails", 1)

    assert_equal 1, result.length
    assert_equal 123, result.first[:github_id]
    assert_equal "commenter1", result.first[:author_login]
    assert_equal "Comment body", result.first[:body]
  end

  # A 404 means the thread is unreadable, not empty. Callers prune cached
  # comments against this response, so an empty array would delete the cache.
  test "should handle comments not found" do
    mock_client = OpenStruct.new
    def mock_client.issue_comments(repo, issue_number)
      raise Octokit::NotFound.new
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_issue_comments("rails", "rails", 999)

    assert_equal Github::ApiClient::ERROR_ISSUE_NOT_FOUND, result[:error]
  end

  test "should handle SAML protected error in fetch_issue_comments" do
    mock_client = OpenStruct.new
    def mock_client.issue_comments(repo, issue_number)
      raise Octokit::SAMLProtected.new
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_issue_comments("rails", "rails", 1)

    assert result.is_a?(Hash)
    assert_includes result[:error], "SAML SSO authorization"
    assert_includes result[:error], "https://docs.github.com"
  end

  # Test connection tests

  test "should test connection successfully" do
    mock_user = OpenStruct.new(login: "testuser")

    mock_client = OpenStruct.new
    def mock_client.user
      OpenStruct.new(login: "testuser")
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.test_connection

    assert result[:success]
  end

  test "should handle invalid token in test connection" do
    mock_client = OpenStruct.new
    def mock_client.user
      raise Octokit::Unauthorized.new
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.test_connection

    assert_not result[:success]
    assert_equal "Invalid GitHub token", result[:error]
  end

  # Rate limiting tests have been removed because check_rate_limit method was removed
  # Rate limit checking now happens only via response headers after each API call

  # Retry logic tests

  test "should fail immediately on TooManyRequests to allow cache fallback" do
    mock_client = OpenStruct.new

    def mock_client.rate_limit
      nil
    end

    def mock_client.repository(full_name)
      error = Octokit::TooManyRequests.new
      def error.response_headers
        { "x-ratelimit-reset" => Time.now.to_i.to_s }
      end
      raise error
    end

    @client.instance_variable_set(:@client, mock_client)

    # Changed behavior: no longer retry on rate limit - fail fast for cache fallback
    assert_raises Octokit::TooManyRequests do
      @client.fetch_repository("rails", "rails")
    end
  end

  test "should raise immediately on TooManyRequests without retries" do
    mock_client = OpenStruct.new

    def mock_client.rate_limit
      nil
    end

    def mock_client.repository(full_name)
      error = Octokit::TooManyRequests.new
      def error.response_headers
        { "x-ratelimit-reset" => Time.now.to_i.to_s }
      end
      raise error
    end

    @client.instance_variable_set(:@client, mock_client)

    # Changed behavior: fail immediately without retries
    assert_raises Octokit::TooManyRequests do
      @client.fetch_repository("rails", "rails")
    end
  end

  test "should retry on ServerError and succeed" do
    call_count = 0
    mock_client = OpenStruct.new

    def mock_client.rate_limit
      nil
    end

    def mock_client.repository(full_name)
      @call_count ||= 0
      @call_count += 1

      if @call_count == 1
        raise Octokit::ServerError.new(message: "Server error")
      else
        OpenStruct.new(
          owner: OpenStruct.new(login: "rails"),
          name: "rails",
          full_name: "rails/rails",
          description: "Ruby on Rails",
          html_url: "https://github.com/rails/rails",
          open_issues_count: 100
        )
      end
    end

    @client.instance_variable_set(:@client, mock_client)

    # Override sleep to avoid waiting
    @client.define_singleton_method(:sleep) { |duration| nil }

    result = @client.fetch_repository("rails", "rails")

    assert_equal "rails", result[:owner]
  end

  test "should raise after max retries on ServerError" do
    mock_client = OpenStruct.new

    def mock_client.rate_limit
      nil
    end

    def mock_client.repository(full_name)
      raise Octokit::ServerError.new(message: "Server error")
    end

    @client.instance_variable_set(:@client, mock_client)

    # Override sleep to avoid waiting
    @client.define_singleton_method(:sleep) { |duration| nil }

    assert_raises Octokit::ServerError do
      @client.fetch_repository("rails", "rails")
    end
  end

  # Private method tests

  test "should normalize repository data correctly" do
    repo = OpenStruct.new(
      owner: OpenStruct.new(login: "rails"),
      name: "rails",
      full_name: "rails/rails",
      description: "Ruby on Rails",
      html_url: "https://github.com/rails/rails",
      open_issues_count: 100
    )

    result = @client.send(:normalize_repository_data, repo)

    assert_equal "rails", result[:owner]
    assert_equal "rails", result[:name]
    assert_equal "rails/rails", result[:full_name]
    assert_equal "Ruby on Rails", result[:description]
    assert_equal "https://github.com/rails/rails", result[:url]
    assert_equal 100, result[:open_issues_count]
  end

  test "should normalize issue data correctly" do
    issue = OpenStruct.new(
      number: 1,
      title: "Test Issue",
      state: "open",
      body: "Issue body",
      user: OpenStruct.new(login: "user1", avatar_url: "https://avatar1.png"),
      labels: [ OpenStruct.new(name: "bug", color: "d73a4a") ],
      assignees: [ OpenStruct.new(login: "assignee1", avatar_url: "https://avatar2.png") ],
      comments: 5,
      created_at: 1.day.ago,
      updated_at: 1.hour.ago
    )

    result = @client.send(:normalize_issue_data, issue)

    assert_equal 1, result[:number]
    assert_equal "Test Issue", result[:title]
    assert_equal "open", result[:state]
    assert_equal "user1", result[:author_login]
    assert_equal 1, result[:labels].length
    assert_equal "bug", result[:labels].first[:name]
  end

  test "should normalize comment data correctly" do
    comment = OpenStruct.new(
      id: 123,
      user: OpenStruct.new(login: "commenter1", avatar_url: "https://avatar3.png"),
      body: "Comment body",
      created_at: 1.hour.ago,
      updated_at: 1.hour.ago
    )

    result = @client.send(:normalize_comment_data, comment)

    assert_equal 123, result[:github_id]
    assert_equal "commenter1", result[:author_login]
    assert_equal "Comment body", result[:body]
  end

  # Tests for nil author handling (safe navigation branches)

  test "should handle nil author in issue data" do
    issue = OpenStruct.new(
      number: 1,
      title: "Test Issue",
      state: "open",
      body: "Issue body",
      user: nil,  # Nil author
      labels: [],
      assignees: [],
      comments: 0,
      created_at: 1.day.ago,
      updated_at: 1.hour.ago
    )

    result = @client.send(:normalize_issue_data, issue)

    assert_equal 1, result[:number]
    assert_nil result[:author_login]
    assert_nil result[:author_avatar_url]
  end

  test "should handle nil author in comment data" do
    comment = OpenStruct.new(
      id: 123,
      user: nil,  # Nil author
      body: "Comment body",
      created_at: 1.hour.ago,
      updated_at: 1.hour.ago
    )

    result = @client.send(:normalize_comment_data, comment)

    assert_equal 123, result[:github_id]
    assert_nil result[:author_login]
    assert_nil result[:author_avatar_url]
    assert_equal "Comment body", result[:body]
  end

  # Search tests

  test "should search issues successfully" do
    mock_search_result = OpenStruct.new(
      items: [
        OpenStruct.new(
          number: 1,
          title: "Bug in search",
          state: "open",
          body: "Search is broken",
          user: OpenStruct.new(login: "user1", avatar_url: "https://avatar1.png"),
          labels: [ OpenStruct.new(name: "bug", color: "d73a4a") ],
          assignees: [],
          comments: 3,
          created_at: 1.day.ago,
          updated_at: 1.hour.ago
        )
      ]
    )

    mock_client = OpenStruct.new
    def mock_client.search_issues(query, options)
      OpenStruct.new(
        items: [
          OpenStruct.new(
            number: 1,
            title: "Bug in search",
            state: "open",
            body: "Search is broken",
            user: OpenStruct.new(login: "user1", avatar_url: "https://avatar1.png"),
            labels: [ OpenStruct.new(name: "bug", color: "d73a4a") ],
            assignees: [],
            comments: 3,
            created_at: 1.day.ago,
            updated_at: 1.hour.ago
          )
        ],
        total_count: 42
      )
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.search_issues("repo:rails/rails bug")

    assert_equal 1, result[:items].length
    assert_equal 42, result[:total_count]
    assert_equal 1, result[:items].first[:number]
    assert_equal "Bug in search", result[:items].first[:title]
    assert_equal "user1", result[:items].first[:author_login]
  end

  test "should handle search issues not found" do
    mock_client = OpenStruct.new
    def mock_client.search_issues(query, options)
      raise Octokit::NotFound.new
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.search_issues("repo:nonexistent/repo query")

    assert result.is_a?(Hash)
    assert_equal "No results found", result[:error]
  end

  test "should handle search unauthorized error" do
    mock_client = OpenStruct.new
    def mock_client.search_issues(query, options)
      raise Octokit::Unauthorized.new
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.search_issues("repo:rails/rails bug")

    assert result.is_a?(Hash)
    assert_equal "Unauthorized - check your GitHub token", result[:error]
  end

  test "should handle SAML protected error in search_issues" do
    mock_client = OpenStruct.new
    def mock_client.search_issues(query, options)
      raise Octokit::SAMLProtected.new
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.search_issues("repo:rails/rails bug")

    assert result.is_a?(Hash)
    assert_includes result[:error], "SAML SSO authorization"
    assert_includes result[:error], "https://docs.github.com"
  end

  # Tests for sleep_time <= 0 branches

  test "should fail immediately on rate limit without sleeping" do
    mock_client = OpenStruct.new

    def mock_client.rate_limit
      nil
    end

    def mock_client.repository(full_name)
      error = Octokit::TooManyRequests.new
      def error.response_headers
        # Reset time in the past (sleep_time will be negative)
        { "x-ratelimit-reset" => (Time.now.to_i - 100).to_s }
      end
      raise error
    end

    @client.instance_variable_set(:@client, mock_client)

    # Track sleep calls
    sleep_calls = []
    @client.define_singleton_method(:sleep) { |duration| sleep_calls << duration }

    # Changed behavior: fail immediately without retries
    assert_raises Octokit::TooManyRequests do
      @client.fetch_repository("rails", "rails")
    end

    # Should not sleep at all
    assert_empty sleep_calls
  end

  # Removed: test "should not sleep when critical rate limit detected"
  # check_rate_limit method was removed in favor of header-only rate limit tracking

  # Tests for fetch_assignable_users

  test "should fetch assignable users successfully" do
    mock_client = OpenStruct.new
    def mock_client.post(path, body)
      {
        data: {
          repository: {
            assignableUsers: {
              nodes: [
                { login: "user1", avatarUrl: "https://example.com/user1.png" },
                { login: "user2", avatarUrl: "https://example.com/user2.png" }
              ],
              pageInfo: {
                hasNextPage: false,
                endCursor: nil
              }
            }
          }
        }
      }
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_assignable_users("rails", "rails")

    assert result.is_a?(Array)
    assert_equal 2, result.length
    assert_equal "user1", result[0][:login]
    assert_equal "user2", result[1][:login]
  end

  test "should handle pagination in fetch_assignable_users" do
    mock_client = OpenStruct.new
    call_count = 0
    def mock_client.post(path, body)
      @call_count ||= 0
      @call_count += 1

      if @call_count == 1
        {
          data: {
            repository: {
              assignableUsers: {
                nodes: [ { login: "user1", avatarUrl: "url1" } ],
                pageInfo: { hasNextPage: true, endCursor: "cursor1" }
              }
            }
          }
        }
      else
        {
          data: {
            repository: {
              assignableUsers: {
                nodes: [ { login: "user2", avatarUrl: "url2" } ],
                pageInfo: { hasNextPage: false, endCursor: nil }
              }
            }
          }
        }
      end
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_assignable_users("rails", "rails")

    assert_equal 2, result.length
  end

  test "should handle GraphQL errors in fetch_assignable_users" do
    mock_client = OpenStruct.new
    def mock_client.post(path, body)
      { errors: [ { message: "GraphQL error" } ] }
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_assignable_users("rails", "rails")

    assert result.is_a?(Hash)
    assert_equal "GraphQL error", result[:error]
  end

  test "should handle exceptions in fetch_assignable_users" do
    mock_client = OpenStruct.new
    def mock_client.post(path, body)
      raise StandardError.new("Network error")
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_assignable_users("rails", "rails")

    assert result.is_a?(Hash)
    assert_equal "Network error", result[:error]
  end

  test "should handle unauthorized error in fetch_assignable_users" do
    mock_client = OpenStruct.new
    def mock_client.post(path, body)
      raise Octokit::Unauthorized.new
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_assignable_users("rails", "rails")

    assert result.is_a?(Hash)
    assert_equal "Unauthorized - check your GitHub token", result[:error]
  end

  # Tests for fetch_issue_project_fields

  test "should fetch project fields successfully" do
    mock_client = OpenStruct.new
    def mock_client.post(path, body)
      {
        data: {
          repository: {
            issueOrPullRequest: {
              projectItems: {
                nodes: [
                  {
                    project: {
                      title: "Sprint Board",
                      number: 1,
                      url: "https://github.com/orgs/test/projects/1"
                    },
                    fieldValues: {
                      nodes: [
                        {
                          __typename: "ProjectV2ItemFieldSingleSelectValue",
                          name: "In Progress",
                          field: { name: "Status" }
                        },
                        {
                          __typename: "ProjectV2ItemFieldNumberValue",
                          number: 5,
                          field: { name: "Estimate" }
                        }
                      ]
                    }
                  }
                ]
              }
            }
          }
        }
      }
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_issue_project_fields("rails", "rails", 123)

    assert result.is_a?(Array)
    assert_equal 1, result.length
    assert_equal "Sprint Board", result[0][:project_title]
    assert_equal "In Progress", result[0][:fields]["Status"]
    assert_equal 5, result[0][:fields]["Estimate"]
  end

  test "should return empty array on error in fetch_issue_project_fields" do
    mock_client = OpenStruct.new
    def mock_client.post(path, body)
      { errors: [ { message: "GraphQL error" } ] }
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_issue_project_fields("rails", "rails", 123)

    assert result.is_a?(Array)
    assert_empty result
  end

  test "should handle exception in fetch_issue_project_fields" do
    mock_client = OpenStruct.new
    def mock_client.post(path, body)
      raise StandardError.new("Network error")
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_issue_project_fields("rails", "rails", 123)

    assert result.is_a?(Array)
    assert_empty result
  end

  # Tests for fetch_issue_timeline

  test "should fetch timeline successfully" do
    mock_client = OpenStruct.new
    def mock_client.post(path, body)
      {
        data: {
          repository: {
            issueOrPullRequest: {
              timelineItems: {
                nodes: [
                  {
                    __typename: "LabeledEvent",
                    id: "LE_123",
                    createdAt: "2025-11-06T12:00:00Z",
                    actor: { login: "user1" },
                    label: { name: "bug", color: "ff0000" }
                  },
                  {
                    __typename: "ProjectV2ItemStatusChangedEvent",
                    id: "PVTE_456",
                    createdAt: "2025-11-06T13:00:00Z",
                    actor: { login: "user2" },
                    previousStatus: "To Do",
                    status: "In Progress",
                    wasAutomated: false,
                    project: { title: "Sprint Board" }
                  }
                ]
              }
            }
          }
        }
      }
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_issue_timeline("rails", "rails", 123)

    assert result.is_a?(Array)
    assert_equal 2, result.length
    assert_equal "labeled", result[0][:type]
    assert_equal "user1", result[0][:actor]
    assert_equal "status_changed", result[1][:type]
    assert_equal "In Progress", result[1][:status]
  end

  test "should return empty array on error in fetch_issue_timeline" do
    mock_client = OpenStruct.new
    def mock_client.post(path, body)
      { errors: [ { message: "GraphQL error" } ] }
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_issue_timeline("rails", "rails", 123)

    assert result.is_a?(Array)
    assert_empty result
  end

  test "should handle exception in fetch_issue_timeline" do
    mock_client = OpenStruct.new
    def mock_client.post(path, body)
      raise StandardError.new("Network error")
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_issue_timeline("rails", "rails", 123)

    assert result.is_a?(Array)
    assert_empty result
  end

  # Tests for different project field types

  test "should handle all project field types" do
    mock_client = OpenStruct.new
    def mock_client.post(path, body)
      {
        data: {
          repository: {
            issueOrPullRequest: {
              projectItems: {
                nodes: [
                  {
                    project: {
                      title: "Test Project",
                      number: 1,
                      url: "https://github.com/orgs/test/projects/1"
                    },
                    fieldValues: {
                      nodes: [
                        {
                          __typename: "ProjectV2ItemFieldTextValue",
                          text: "Some text",
                          field: { name: "Description" }
                        },
                        {
                          __typename: "ProjectV2ItemFieldDateValue",
                          date: "2025-11-15",
                          field: { name: "Due Date" }
                        },
                        {
                          __typename: "ProjectV2ItemFieldIterationValue",
                          title: "Sprint 5",
                          field: { name: "Sprint" }
                        }
                      ]
                    }
                  }
                ]
              }
            }
          }
        }
      }
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_issue_project_fields("rails", "rails", 123)

    assert_equal 1, result.length
    assert_equal "Some text", result[0][:fields]["Description"]
    assert_equal "2025-11-15", result[0][:fields]["Due Date"]
    assert_equal "Sprint 5", result[0][:fields]["Sprint"]
  end

  test "should handle empty date field" do
    mock_client = OpenStruct.new
    def mock_client.post(path, body)
      {
        data: {
          repository: {
            issueOrPullRequest: {
              projectItems: {
                nodes: [
                  {
                    project: {
                      title: "Test Project",
                      number: 1,
                      url: "https://github.com/orgs/test/projects/1"
                    },
                    fieldValues: {
                      nodes: [
                        {
                          __typename: "ProjectV2ItemFieldDateValue",
                          date: nil,
                          field: { name: "Due Date" }
                        }
                      ]
                    }
                  }
                ]
              }
            }
          }
        }
      }
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_issue_project_fields("rails", "rails", 123)

    assert_equal 1, result.length
    assert_equal "", result[0][:fields]["Due Date"]
  end

  test "should skip Title field in project fields" do
    mock_client = OpenStruct.new
    def mock_client.post(path, body)
      {
        data: {
          repository: {
            issueOrPullRequest: {
              projectItems: {
                nodes: [
                  {
                    project: {
                      title: "Test Project",
                      number: 1,
                      url: "https://github.com/orgs/test/projects/1"
                    },
                    fieldValues: {
                      nodes: [
                        {
                          __typename: "ProjectV2ItemFieldTextValue",
                          text: "Issue title",
                          field: { name: "Title" }
                        },
                        {
                          __typename: "ProjectV2ItemFieldTextValue",
                          text: "Other value",
                          field: { name: "Other" }
                        }
                      ]
                    }
                  }
                ]
              }
            }
          }
        }
      }
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_issue_project_fields("rails", "rails", 123)

    assert_equal 1, result.length
    assert_nil result[0][:fields]["Title"]
    assert_equal "Other value", result[0][:fields]["Other"]
  end

  test "should handle unknown field type" do
    mock_client = OpenStruct.new
    def mock_client.post(path, body)
      {
        data: {
          repository: {
            issueOrPullRequest: {
              projectItems: {
                nodes: [
                  {
                    project: {
                      title: "Test Project",
                      number: 1,
                      url: "https://github.com/orgs/test/projects/1"
                    },
                    fieldValues: {
                      nodes: [
                        {
                          __typename: "UnknownFieldType",
                          someValue: "test",
                          field: { name: "Unknown" }
                        },
                        {
                          __typename: "ProjectV2ItemFieldTextValue",
                          text: "Known value",
                          field: { name: "Known" }
                        }
                      ]
                    }
                  }
                ]
              }
            }
          }
        }
      }
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_issue_project_fields("rails", "rails", 123)

    assert_equal 1, result.length
    # Unknown field should be skipped
    assert_nil result[0][:fields]["Unknown"]
    # Known field should be included
    assert_equal "Known value", result[0][:fields]["Known"]
  end

  # Tests for different timeline event types

  test "should normalize inline review comments" do
    mock_client = OpenStruct.new
    def mock_client.post(path, body)
      {
        data: {
          repository: {
            issueOrPullRequest: {
              timelineItems: {
                nodes: [
                  {
                    __typename: "PullRequestReview",
                    id: "PRR_1",
                    createdAt: "2025-11-06T12:00:00Z",
                    state: "COMMENTED",
                    author: { login: "reviewer", avatarUrl: "https://example.com/a.png" },
                    body: "A few notes.",
                    comments: {
                      totalCount: 2,
                      nodes: [
                        {
                          id: "PRRC_1",
                          body: "Extract this.",
                          path: "app/models/issue.rb",
                          diffHunk: "@@ -1 +1 @@\n+code",
                          outdated: false,
                          line: 12,
                          originalLine: 10,
                          createdAt: "2025-11-06T12:01:00Z",
                          author: { login: "reviewer", avatarUrl: "https://example.com/a.png" }
                        }
                      ]
                    }
                  }
                ]
              }
            }
          }
        }
      }
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    review = @client.fetch_issue_timeline("rails", "rails", 123).first

    assert_equal "review", review[:type]
    assert_equal "A few notes.", review[:body]
    assert_equal 2, review[:comments_total]

    comment = review[:comments].first
    assert_equal "app/models/issue.rb", comment[:path]
    assert_equal "Extract this.", comment[:body]
    assert_equal 12, comment[:line]
    assert_equal "reviewer", comment[:actor]
  end

  # An outdated comment has no current line, so it falls back to the line it
  # was originally left on.
  test "should fall back to the original line for an outdated review comment" do
    mock_client = OpenStruct.new
    def mock_client.post(path, body)
      {
        data: {
          repository: {
            issueOrPullRequest: {
              timelineItems: {
                nodes: [
                  {
                    __typename: "PullRequestReview",
                    id: "PRR_2",
                    createdAt: "2025-11-06T12:00:00Z",
                    state: "COMMENTED",
                    author: { login: "reviewer" },
                    body: nil,
                    comments: {
                      totalCount: 1,
                      nodes: [
                        {
                          id: "PRRC_2",
                          body: "Stale note.",
                          path: "a.rb",
                          diffHunk: nil,
                          outdated: true,
                          line: nil,
                          originalLine: 7,
                          createdAt: "2025-11-06T12:01:00Z",
                          author: { login: "reviewer" }
                        }
                      ]
                    }
                  }
                ]
              }
            }
          }
        }
      }
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    comment = @client.fetch_issue_timeline("rails", "rails", 123).first[:comments].first

    assert_equal 7, comment[:line]
    assert comment[:outdated]
  end

  test "should handle a review with no comments" do
    mock_client = OpenStruct.new
    def mock_client.post(path, body)
      {
        data: {
          repository: {
            issueOrPullRequest: {
              timelineItems: {
                nodes: [
                  {
                    __typename: "PullRequestReview",
                    id: "PRR_3",
                    createdAt: "2025-11-06T12:00:00Z",
                    state: "APPROVED",
                    author: { login: "reviewer" },
                    body: "LGTM"
                  }
                ]
              }
            }
          }
        }
      }
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    review = @client.fetch_issue_timeline("rails", "rails", 123).first

    assert_empty review[:comments]
    assert_equal 0, review[:comments_total]
  end

  test "should handle unlabeled event" do
    mock_client = OpenStruct.new
    def mock_client.post(path, body)
      {
        data: {
          repository: {
            issueOrPullRequest: {
              timelineItems: {
                nodes: [
                  {
                    __typename: "UnlabeledEvent",
                    id: "ULE_123",
                    createdAt: "2025-11-06T12:00:00Z",
                    actor: { login: "user1" },
                    label: { name: "bug", color: "ff0000" }
                  }
                ]
              }
            }
          }
        }
      }
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_issue_timeline("rails", "rails", 123)

    assert_equal 1, result.length
    assert_equal "unlabeled", result[0][:type]
    assert_equal "user1", result[0][:actor]
    assert_equal "bug", result[0][:label][:name]
  end

  test "should handle milestoned event" do
    mock_client = OpenStruct.new
    def mock_client.post(path, body)
      {
        data: {
          repository: {
            issueOrPullRequest: {
              timelineItems: {
                nodes: [
                  {
                    __typename: "MilestonedEvent",
                    id: "ME_123",
                    createdAt: "2025-11-06T12:00:00Z",
                    actor: { login: "user1" },
                    milestoneTitle: "v1.0"
                  }
                ]
              }
            }
          }
        }
      }
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_issue_timeline("rails", "rails", 123)

    assert_equal 1, result.length
    assert_equal "milestoned", result[0][:type]
    assert_equal "user1", result[0][:actor]
    assert_equal "v1.0", result[0][:milestone_title]
  end

  test "should handle demilestoned event" do
    mock_client = OpenStruct.new
    def mock_client.post(path, body)
      {
        data: {
          repository: {
            issueOrPullRequest: {
              timelineItems: {
                nodes: [
                  {
                    __typename: "DemilestonedEvent",
                    id: "DME_123",
                    createdAt: "2025-11-06T12:00:00Z",
                    actor: { login: "user1" },
                    milestoneTitle: "v0.9"
                  }
                ]
              }
            }
          }
        }
      }
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_issue_timeline("rails", "rails", 123)

    assert_equal 1, result.length
    assert_equal "demilestoned", result[0][:type]
    assert_equal "user1", result[0][:actor]
    assert_equal "v0.9", result[0][:milestone_title]
  end

  test "should handle added to project event" do
    mock_client = OpenStruct.new
    def mock_client.post(path, body)
      {
        data: {
          repository: {
            issueOrPullRequest: {
              timelineItems: {
                nodes: [
                  {
                    __typename: "AddedToProjectV2Event",
                    id: "APE_123",
                    createdAt: "2025-11-06T12:00:00Z",
                    actor: { login: "user1" },
                    project: { title: "Sprint Board", number: 1 }
                  }
                ]
              }
            }
          }
        }
      }
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_issue_timeline("rails", "rails", 123)

    assert_equal 1, result.length
    assert_equal "added_to_project", result[0][:type]
    assert_equal "user1", result[0][:actor]
    assert_equal "Sprint Board", result[0][:project_title]
    assert_equal 1, result[0][:project_number]
  end

  test "should handle removed from project event" do
    mock_client = OpenStruct.new
    def mock_client.post(path, body)
      {
        data: {
          repository: {
            issueOrPullRequest: {
              timelineItems: {
                nodes: [
                  {
                    __typename: "RemovedFromProjectV2Event",
                    id: "RPE_123",
                    createdAt: "2025-11-06T12:00:00Z",
                    actor: { login: "user1" },
                    project: { title: "Old Project" }
                  }
                ]
              }
            }
          }
        }
      }
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_issue_timeline("rails", "rails", 123)

    assert_equal 1, result.length
    assert_equal "removed_from_project", result[0][:type]
    assert_equal "user1", result[0][:actor]
    assert_equal "Old Project", result[0][:project_title]
  end

  test "should handle issue comment in timeline" do
    mock_client = OpenStruct.new
    def mock_client.post(path, body)
      {
        data: {
          repository: {
            issueOrPullRequest: {
              timelineItems: {
                nodes: [
                  {
                    __typename: "IssueComment",
                    id: "IC_123",
                    createdAt: "2025-11-06T12:00:00Z",
                    author: {
                      login: "commenter1",
                      avatarUrl: "https://example.com/avatar.png"
                    },
                    body: "This is a comment",
                    authorAssociation: "MEMBER"
                  }
                ]
              }
            }
          }
        }
      }
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_issue_timeline("rails", "rails", 123)

    assert_equal 1, result.length
    assert_equal "comment", result[0][:type]
    assert_equal "commenter1", result[0][:actor]
    assert_equal "https://example.com/avatar.png", result[0][:avatar_url]
    assert_equal "This is a comment", result[0][:body]
    assert_equal "MEMBER", result[0][:author_association]
  end

  test "should handle pull request timeline events" do
    mock_client = OpenStruct.new
    def mock_client.post(path, body)
      {
        data: {
          repository: {
            issueOrPullRequest: {
              timelineItems: {
                nodes: [
                  {
                    __typename: "MergedEvent",
                    id: "ME_1",
                    createdAt: "2025-11-06T12:00:00Z",
                    actor: { login: "maintainer" },
                    mergeRefName: "main"
                  },
                  {
                    __typename: "ReadyForReviewEvent",
                    id: "RFR_1",
                    createdAt: "2025-11-06T12:05:00Z",
                    actor: { login: "contributor" }
                  },
                  {
                    __typename: "ReviewRequestedEvent",
                    id: "RR_1",
                    createdAt: "2025-11-06T12:10:00Z",
                    actor: { login: "contributor" },
                    requestedReviewer: { login: "maintainer" }
                  },
                  {
                    __typename: "PullRequestReview",
                    id: "PRR_1",
                    createdAt: "2025-11-06T12:15:00Z",
                    state: "APPROVED",
                    author: { login: "maintainer", avatarUrl: "https://example.com/avatar.png" },
                    body: "LGTM"
                  }
                ]
              }
            }
          }
        }
      }
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_issue_timeline("rails", "rails", 123)

    assert_equal 4, result.length

    merged = result[0]
    assert_equal "merged", merged[:type]
    assert_equal "maintainer", merged[:actor]
    assert_equal "main", merged[:merge_ref_name]

    assert_equal "ready_for_review", result[1][:type]

    review_requested = result[2]
    assert_equal "review_requested", review_requested[:type]
    assert_equal "maintainer", review_requested[:reviewer]

    review = result[3]
    assert_equal "review", review[:type]
    assert_equal "APPROVED", review[:review_state]
    assert_equal "LGTM", review[:body]
  end

  test "should fall back to team name for requested reviewers" do
    mock_client = OpenStruct.new
    def mock_client.post(path, body)
      {
        data: {
          repository: {
            issueOrPullRequest: {
              timelineItems: {
                nodes: [
                  {
                    __typename: "ReviewRequestedEvent",
                    id: "RR_2",
                    createdAt: "2025-11-06T12:10:00Z",
                    actor: { login: "contributor" },
                    requestedReviewer: { name: "platform-team" }
                  }
                ]
              }
            }
          }
        }
      }
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_issue_timeline("rails", "rails", 123)

    assert_equal "platform-team", result[0][:reviewer]
  end

  test "should handle review requested event without a reviewer" do
    mock_client = OpenStruct.new
    def mock_client.post(path, body)
      {
        data: {
          repository: {
            issueOrPullRequest: {
              timelineItems: {
                nodes: [
                  {
                    __typename: "ReviewRequestedEvent",
                    id: "RR_3",
                    createdAt: "2025-11-06T12:10:00Z",
                    actor: { login: "contributor" }
                  }
                ]
              }
            }
          }
        }
      }
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_issue_timeline("rails", "rails", 123)

    assert_nil result[0][:reviewer]
  end

  test "should handle unknown timeline event type" do
    mock_client = OpenStruct.new
    def mock_client.post(path, body)
      {
        data: {
          repository: {
            issueOrPullRequest: {
              timelineItems: {
                nodes: [
                  {
                    __typename: "UnknownEventType",
                    id: "UNK_123",
                    createdAt: "2025-11-06T12:00:00Z"
                  },
                  {
                    __typename: "LabeledEvent",
                    id: "LE_456",
                    createdAt: "2025-11-06T13:00:00Z",
                    actor: { login: "user1" },
                    label: { name: "bug", color: "ff0000" }
                  }
                ]
              }
            }
          }
        }
      }
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_issue_timeline("rails", "rails", 123)

    # Unknown event should return nil and be filtered out
    # But the labeled event should be included
    assert_equal 1, result.length
    assert_equal "labeled", result[0][:type]
  end

  test "should use correct GraphQL endpoint for GHE" do
    ghe_client = Github::ApiClient.new(token: @token, domain: "github.example.com")
    mock_client = OpenStruct.new

    # Track which path is used
    called_path = nil
    def mock_client.post(path, body)
      @called_path = path
      {
        data: {
          repository: {
            issueOrPullRequest: {
              projectItems: { nodes: [] }
            }
          }
        }
      }
    end
    def mock_client.rate_limit
      nil
    end
    def mock_client.called_path
      @called_path
    end

    ghe_client.instance_variable_set(:@client, mock_client)

    ghe_client.fetch_issue_project_fields("rails", "rails", 123)

    # GHE should use /api/graphql
    assert_equal "/api/graphql", mock_client.called_path
  end

  test "should use correct GraphQL endpoint for github.com" do
    mock_client = OpenStruct.new

    # Track which path is used
    called_path = nil
    def mock_client.post(path, body)
      @called_path = path
      {
        data: {
          repository: {
            issueOrPullRequest: {
              projectItems: { nodes: [] }
            }
          }
        }
      }
    end
    def mock_client.rate_limit
      nil
    end
    def mock_client.called_path
      @called_path
    end

    @client.instance_variable_set(:@client, mock_client)

    @client.fetch_issue_project_fields("rails", "rails", 123)

    # GitHub.com should use /graphql
    assert_equal "/graphql", mock_client.called_path
  end

  # Error handling across the REST fetch methods

  {
    "fetch_issues" => { octokit: :issues, args: [ "rails", "rails" ] },
    "fetch_issue" => { octokit: :issue, args: [ "rails", "rails", 1 ] },
    "fetch_issue_comments" => { octokit: :issue_comments, args: [ "rails", "rails", 1 ] },
    "fetch_labels" => { octokit: :labels, args: [ "rails", "rails" ] },
    "fetch_pull_request" => { octokit: :pull_request, args: [ "rails", "rails", 1 ] },
    "fetch_pull_request_commits" => { octokit: :pull_request_commits, args: [ "rails", "rails", 1 ] },
    "fetch_pull_request_files" => { octokit: :pull_request_files, args: [ "rails", "rails", 1 ] }
  }.each do |method, config|
    test "#{method} surfaces SAML protected errors" do
      stub_octokit_failure(config[:octokit], Octokit::SAMLProtected)

      result = @client.public_send(method, *config[:args])

      assert_includes result[:error], "SAML SSO authorization"
    end
  end

  test "fetch_issues reports a missing repository" do
    stub_octokit_failure(:issues, Octokit::NotFound)

    assert_equal "Repository not found", @client.fetch_issues("rails", "rails")[:error]
  end

  test "fetch_issues reports an unauthorized token" do
    stub_octokit_failure(:issues, Octokit::Unauthorized)

    assert_equal "Unauthorized - check your GitHub token", @client.fetch_issues("rails", "rails")[:error]
  end

  test "fetch_issue reports a missing issue" do
    stub_octokit_failure(:issue, Octokit::NotFound)

    assert_equal "Issue not found", @client.fetch_issue("rails", "rails", 1)[:error]
  end

  test "fetch_issue_comments reports a missing issue rather than an empty thread" do
    stub_octokit_failure(:issue_comments, Octokit::NotFound)

    result = @client.fetch_issue_comments("rails", "rails", 1)

    assert_equal Github::ApiClient::ERROR_ISSUE_NOT_FOUND, result[:error]
  end

  test "fetch_labels returns no labels when the repository is missing" do
    stub_octokit_failure(:labels, Octokit::NotFound)

    assert_equal [], @client.fetch_labels("rails", "rails")
  end

  test "fetch_labels reports an unauthorized token" do
    stub_octokit_failure(:labels, Octokit::Unauthorized)

    assert_equal "Unauthorized - check your GitHub token", @client.fetch_labels("rails", "rails")[:error]
  end

  test "fetch_labels returns labels from the API" do
    mock_client = OpenStruct.new
    def mock_client.labels(_full_name, _options)
      [ OpenStruct.new(name: "bug", color: "d73a4a") ]
    end
    def mock_client.rate_limit
      nil
    end
    @client.instance_variable_set(:@client, mock_client)

    labels = @client.fetch_labels("rails", "rails")

    assert_equal 1, labels.length
    assert_equal "bug", labels.first.name
  end

  # GraphQL failures degrade to empty results rather than raising

  test "fetch_issue_project_fields returns empty on transport errors" do
    @client.stubs(:graphql_query).raises(StandardError.new("boom"))

    assert_equal [], @client.fetch_issue_project_fields("rails", "rails", 1)
  end

  test "fetch_issue_timeline returns empty on transport errors" do
    @client.stubs(:graphql_query).raises(StandardError.new("boom"))

    assert_equal [], @client.fetch_issue_timeline("rails", "rails", 1)
  end

  test "fetch_assignable_users reports transport errors" do
    @client.stubs(:graphql_query).raises(StandardError.new("boom"))

    assert_equal "boom", @client.fetch_assignable_users("rails", "rails")[:error]
  end

  # Pull request endpoints

  test "fetch_pull_request returns the diff statistics the issue endpoint omits" do
    stub_octokit(:pull_request, {
      commits: 12,
      changed_files: 3,
      additions: 608,
      deletions: 42,
      merged_at: nil,
      draft: false
    })

    result = @client.fetch_pull_request("rails", "rails", 1)

    assert_equal 12, result[:commits_count]
    assert_equal 3, result[:changed_files_count]
    assert_equal 608, result[:additions]
    assert_equal 42, result[:deletions]
    refute result[:draft]
  end

  test "fetch_pull_request reports a missing pull request" do
    stub_octokit_failure(:pull_request, Octokit::NotFound)

    assert_equal "Issue not found", @client.fetch_pull_request("rails", "rails", 1)[:error]
  end

  test "fetch_pull_request_commits flattens the nested commit payload" do
    stub_octokit(:pull_request_commits, [ {
      sha: "abc1234def",
      commit: {
        message: "Fix the thing\n\nBecause it was broken.\nTwice.",
        author: { name: "Eric Boehs", date: "2025-01-02T03:04:05Z" }
      },
      author: { login: "ericboehs", avatar_url: "https://example.com/a.png" }
    } ])

    commit = @client.fetch_pull_request_commits("rails", "rails", 1).first

    assert_equal "abc1234def", commit[:sha]
    assert_equal "Fix the thing", commit[:subject]
    assert_equal "Because it was broken.\nTwice.", commit[:body]
    assert_equal "Eric Boehs", commit[:author_name]
    assert_equal "ericboehs", commit[:author_login]
    assert_equal "https://example.com/a.png", commit[:author_avatar_url]
  end

  test "fetch_pull_request_commits handles a subject-only message" do
    stub_octokit(:pull_request_commits, [ {
      sha: "abc",
      commit: { message: "Just a subject", author: { name: "Eric", date: nil } },
      author: nil
    } ])

    commit = @client.fetch_pull_request_commits("rails", "rails", 1).first

    assert_equal "Just a subject", commit[:subject]
    assert_equal "", commit[:body]
  end

  # Commits authored from an email address with no linked GitHub account have
  # git metadata but no `author`, which must not blow up the normalizer.
  test "fetch_pull_request_commits tolerates a commit with no GitHub account" do
    stub_octokit(:pull_request_commits, [ {
      sha: "abc",
      commit: { message: "Unlinked", author: { name: "Somebody", date: nil } },
      author: nil
    } ])

    commit = @client.fetch_pull_request_commits("rails", "rails", 1).first

    assert_nil commit[:author_login]
    assert_nil commit[:author_avatar_url]
    assert_equal "Somebody", commit[:author_name]
  end

  test "fetch_pull_request_files normalizes each changed file" do
    stub_octokit(:pull_request_files, [ {
      filename: "app/models/issue.rb",
      previous_filename: "app/models/old.rb",
      status: "renamed",
      additions: 2,
      deletions: 1,
      changes: 3,
      patch: "@@ -1 +1 @@"
    } ])

    file = @client.fetch_pull_request_files("rails", "rails", 1).first

    assert_equal "app/models/issue.rb", file[:filename]
    assert_equal "app/models/old.rb", file[:previous_filename]
    assert_equal "renamed", file[:status]
    assert_equal 3, file[:changes]
    assert_equal "@@ -1 +1 @@", file[:patch]
  end

  # GitHub omits `patch` for binary files and oversized diffs. That is normal,
  # not an error, so it has to survive normalization as a nil.
  test "fetch_pull_request_files keeps a missing patch as nil" do
    stub_octokit(:pull_request_files, [ {
      filename: "logo.png", status: "added", additions: 0, deletions: 0, changes: 0
    } ])

    assert_nil @client.fetch_pull_request_files("rails", "rails", 1).first[:patch]
  end

  test "fetch_pull_request_files reports a missing pull request" do
    stub_octokit_failure(:pull_request_files, Octokit::NotFound)

    assert_equal "Issue not found", @client.fetch_pull_request_files("rails", "rails", 1)[:error]
  end

  test "fetch_pull_request_commits reports a missing pull request" do
    stub_octokit_failure(:pull_request_commits, Octokit::NotFound)

    assert_equal "Issue not found", @client.fetch_pull_request_commits("rails", "rails", 1)[:error]
  end

  test "fetch_file_contents decodes the base64 blob GitHub returns" do
    stub_octokit(:contents, {
      path: "README.md", size: 12, encoding: "base64", content: Base64.encode64("# Hello\nworld")
    })

    result = @client.fetch_file_contents("rails", "rails", "README.md", ref: "abc123")

    assert_equal "# Hello\nworld", result[:content]
    assert_equal "README.md", result[:path]
    assert_equal 12, result[:size]
    refute result[:binary]
  end

  # Anything that is not valid UTF-8 cannot be shown as text and must not be
  # passed through into the response.
  test "fetch_file_contents flags a binary blob instead of returning bytes" do
    stub_octokit(:contents, {
      path: "logo.png", size: 4, encoding: "base64", content: Base64.encode64("\x89PNG\xFF\xFE".b)
    })

    result = @client.fetch_file_contents("rails", "rails", "logo.png", ref: "abc123")

    assert result[:binary]
    assert_nil result[:content]
  end

  # GitHub reports a blob it declined to inline with encoding "none".
  # One endpoint serves both shapes, so the result says which one came back
  # rather than leaving the caller to sniff it.
  test "fetch_contents tags a directory listing" do
    stub_octokit(:contents, [
      { name: "README.md", path: "README.md", type: "file", size: 12 },
      { name: "app", path: "app", type: "dir", size: 0 }
    ])

    result = @client.fetch_contents("rails", "rails", "")

    assert_equal :directory, result[:type]
    assert_equal %w[app README.md], result[:entries].map { |entry| entry[:name] }
  end

  # Directories first, then files, each alphabetically and case-insensitively.
  test "fetch_contents sorts directories ahead of files" do
    stub_octokit(:contents, [
      { name: "zebra.rb", path: "zebra.rb", type: "file", size: 1 },
      { name: "Gemfile", path: "Gemfile", type: "file", size: 1 },
      { name: "lib", path: "lib", type: "dir", size: 0 },
      { name: "App", path: "App", type: "dir", size: 0 }
    ])

    assert_equal %w[App lib Gemfile zebra.rb],
      @client.fetch_contents("rails", "rails", "")[:entries].map { |entry| entry[:name] }
  end

  test "fetch_contents tags a file and decodes it" do
    stub_octokit(:contents, {
      path: "README.md", size: 12, encoding: "base64", content: Base64.encode64("# Hi")
    })

    result = @client.fetch_contents("rails", "rails", "README.md")

    assert_equal :file, result[:type]
    assert_equal "# Hi", result[:content]
  end

  # An unreadable blob is an error, not a file with a :type.
  test "fetch_contents does not tag an error as a file" do
    stub_octokit(:contents, { path: "big.csv", size: 2_000_000, encoding: "none", content: "" })

    result = @client.fetch_contents("rails", "rails", "big.csv")

    assert_equal "File is too large to display", result[:error]
    assert_nil result[:type]
  end

  test "fetch_contents omits a blank ref so GitHub uses the default branch" do
    captured = nil
    mock_client = OpenStruct.new
    mock_client.define_singleton_method(:contents) { |_repo, **options| captured = options; [] }
    mock_client.define_singleton_method(:rate_limit) { nil }
    @client.instance_variable_set(:@client, mock_client)

    @client.fetch_contents("rails", "rails", "app")
    assert_equal({ path: "app" }, captured)

    @client.fetch_contents("rails", "rails", "app", ref: "main")
    assert_equal({ path: "app", ref: "main" }, captured)
  end

  test "fetch_contents reports a missing path" do
    stub_octokit_failure(:contents, Octokit::NotFound)

    assert_equal "File not found", @client.fetch_contents("rails", "rails", "nope")[:error]
  end

  test "fetch_file_contents reports a blob GitHub refused to inline" do
    stub_octokit(:contents, { path: "big.csv", size: 2_000_000, encoding: "none", content: "" })

    assert_equal "File is too large to display",
      @client.fetch_file_contents("rails", "rails", "big.csv", ref: "abc123")[:error]
  end

  # Over 1 MB the endpoint answers 403 rather than a size field.
  test "fetch_file_contents treats a forbidden response as too large" do
    stub_octokit_failure(:contents, Octokit::Forbidden)

    assert_equal "File is too large to display",
      @client.fetch_file_contents("rails", "rails", "big.bin", ref: "abc123")[:error]
  end

  test "fetch_file_contents reports a missing file" do
    stub_octokit_failure(:contents, Octokit::NotFound)

    assert_equal "File not found",
      @client.fetch_file_contents("rails", "rails", "nope.rb", ref: "abc123")[:error]
  end

  # A directory answers with an array of entries, which no file view can show.
  test "fetch_file_contents rejects a directory path" do
    stub_octokit(:contents, [ { path: "app/models/issue.rb" } ])

    assert_equal "File not found",
      @client.fetch_file_contents("rails", "rails", "app/models", ref: "abc123")[:error]
  end

  test "fetch_pull_request exposes the head SHA so files can be read at that revision" do
    stub_octokit(:pull_request, { commits: 1, head: { sha: "deadbeef" } })

    assert_equal "deadbeef", @client.fetch_pull_request("rails", "rails", 1)[:head_sha]
  end

  private

  def stub_octokit(octokit_method, value)
    mock_client = OpenStruct.new
    mock_client.define_singleton_method(octokit_method) { |*_args| value }
    mock_client.define_singleton_method(:rate_limit) { nil }
    @client.instance_variable_set(:@client, mock_client)
  end

  def stub_octokit_failure(octokit_method, error_class)
    mock_client = OpenStruct.new
    mock_client.define_singleton_method(octokit_method) do |*_args|
      raise error_class.new
    end
    mock_client.define_singleton_method(:rate_limit) { nil }
    @client.instance_variable_set(:@client, mock_client)
  end

  # Tests for search_assignable_users

  test "should search assignable users server-side in one page" do
    mock_client = OpenStruct.new
    def mock_client.post(path, body)
      @body = body
      {
        data: { repository: { assignableUsers: {
          nodes: [ { login: "zed", avatarUrl: "https://example.com/zed.png" } ]
        } } }
      }
    end
    def mock_client.captured_body = @body
    def mock_client.rate_limit = nil
    @client.instance_variable_set(:@client, mock_client)

    result = @client.search_assignable_users("rails", "rails", "zed", limit: 20)

    assert_equal [ "zed" ], result.map { |user| user[:login] }
    sent = JSON.parse(mock_client.captured_body)
    assert_equal "zed", sent.dig("variables", "query")
    assert_equal 20, sent.dig("variables", "first")
  end

  test "should return no assignable users when the search errors" do
    mock_client = OpenStruct.new
    def mock_client.post(path, body)
      raise Octokit::Error.new(method: :post, url: "x", status: 500)
    end
    def mock_client.rate_limit = nil
    @client.instance_variable_set(:@client, mock_client)

    assert_equal [], @client.search_assignable_users("rails", "rails", "zed")
  end

  # A huge enterprise org would otherwise page forever.
  test "should stop paging assignable users at the configured cap" do
    mock_client = OpenStruct.new
    def mock_client.post(path, body)
      @calls = (@calls || 0) + 1
      {
        data: { repository: { assignableUsers: {
          nodes: [ { login: "user#{@calls}", avatarUrl: nil } ],
          pageInfo: { hasNextPage: true, endCursor: "cursor#{@calls}" }
        } } }
      }
    end
    def mock_client.calls = @calls
    def mock_client.rate_limit = nil
    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_assignable_users("rails", "rails")

    assert_equal Github::ApiConfiguration::MAX_ASSIGNABLE_USER_PAGES, mock_client.calls
    assert_equal Github::ApiConfiguration::MAX_ASSIGNABLE_USER_PAGES, result.length
  end
end
