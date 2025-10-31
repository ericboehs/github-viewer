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
    mock_results = OpenStruct.new(items: [
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
    ])
    mock_rate_limit = OpenStruct.new(remaining: 5000)
    mock_response = OpenStruct.new(headers: {})

    # Mock all Octokit calls
    mock_octokit_client.expects(:rate_limit).returns(mock_rate_limit)
    mock_octokit_client.expects(:search_issues).with("test query", has_entry(:sort, "created")).returns(mock_results)
    mock_octokit_client.stubs(:last_response).returns(mock_response)
    @client.instance_variable_set(:@client, mock_octokit_client)

    results = @client.search_issues("test query", sort: "created")
    assert_equal 1, results.length
  end

  test "should pass order parameter to search" do
    mock_octokit_client = mock("OctokitClient")
    mock_results = OpenStruct.new(items: [
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
    ])
    mock_rate_limit = OpenStruct.new(remaining: 5000)
    mock_response = OpenStruct.new(headers: {})

    # Mock all Octokit calls
    mock_octokit_client.expects(:rate_limit).returns(mock_rate_limit)
    mock_octokit_client.expects(:search_issues).with("test query", has_entry(:order, "asc")).returns(mock_results)
    mock_octokit_client.stubs(:last_response).returns(mock_response)
    @client.instance_variable_set(:@client, mock_octokit_client)

    results = @client.search_issues("test query", order: "asc")
    assert_equal 1, results.length
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

    assert_equal [], result
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

  # Rate limiting tests

  test "should not sleep when rate limit is high" do
    mock_rate_limit = OpenStruct.new(remaining: 500, limit: 5000, resets_at: Time.now + 300)
    mock_client = OpenStruct.new(rate_limit: mock_rate_limit)

    @client.instance_variable_set(:@client, mock_client)

    # Override sleep to verify it's NOT called
    sleep_called = false
    @client.define_singleton_method(:sleep) { |duration| sleep_called = true }

    @client.send(:check_rate_limit)

    assert_not sleep_called
  end

  test "should not sleep for warning threshold to allow fast fallback" do
    mock_rate_limit = OpenStruct.new(remaining: 150, limit: 5000, resets_at: Time.now + 300)
    mock_client = OpenStruct.new(rate_limit: mock_rate_limit)

    @client.instance_variable_set(:@client, mock_client)

    sleep_duration = nil
    @client.define_singleton_method(:sleep) { |duration| sleep_duration = duration }

    @client.send(:check_rate_limit)

    # Changed behavior: no longer sleep on warnings to allow fast cache fallback
    assert_nil sleep_duration
  end

  test "should not sleep for critical rate limit to allow fast fallback" do
    mock_rate_limit = OpenStruct.new(remaining: 40, limit: 5000, resets_at: Time.now + 2)
    mock_client = OpenStruct.new(rate_limit: mock_rate_limit)

    @client.instance_variable_set(:@client, mock_client)

    sleep_duration = nil
    @client.define_singleton_method(:sleep) { |duration| sleep_duration = duration }

    @client.send(:check_rate_limit)

    # Changed behavior: no longer sleep on critical to allow fast cache fallback
    assert_nil sleep_duration
  end

  test "should handle nil rate limit gracefully" do
    mock_client = OpenStruct.new(rate_limit: nil)
    @client.instance_variable_set(:@client, mock_client)

    assert_nothing_raised do
      @client.send(:check_rate_limit)
    end
  end

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
        ]
      )
    end
    def mock_client.rate_limit
      nil
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.search_issues("repo:rails/rails bug")

    assert_equal 1, result.length
    assert_equal 1, result.first[:number]
    assert_equal "Bug in search", result.first[:title]
    assert_equal "user1", result.first[:author_login]
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

  test "should not sleep when critical rate limit detected" do
    # Mock a rate limit where reset time is in the past
    mock_rate_limit = OpenStruct.new(
      remaining: 40,
      limit: 5000,
      resets_at: Time.now - 10  # In the past
    )
    mock_client = OpenStruct.new(rate_limit: mock_rate_limit)

    @client.instance_variable_set(:@client, mock_client)

    # Track sleep calls
    sleep_calls = []
    @client.define_singleton_method(:sleep) { |duration| sleep_calls << duration }

    @client.send(:check_rate_limit)

    # Changed behavior: no longer sleep on critical to allow fast cache fallback
    assert_empty sleep_calls
  end
end
