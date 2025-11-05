# frozen_string_literal: true

module Github
  # GitHub API client with token-based authentication, rate limiting, and retries
  # :reek:TooManyStatements - Complex API client with rate limiting and error handling
  # :reek:DataClump - owner/repo_name are GitHub's standard repository identifiers
  # :reek:MissingSafeMethod - validate_config! raises by design for invalid config
  # :reek:TooManyMethods - API client provides comprehensive GitHub API access
  # :reek:InstanceVariableAssumption - Client caches rate limit data
  # :reek:DuplicateMethodCall - Client response accessed for readability
  # :reek:FeatureEnvy - Methods delegate to rate_limit and headers objects
  class ApiClient
    include ActiveSupport::Configurable

    # Error raised when client configuration is invalid
    class ConfigurationError < StandardError; end
    # Error raised when GitHub authentication fails
    class AuthenticationError < StandardError; end

    # Error message constants
    ERROR_REPOSITORY_NOT_FOUND = "Repository not found"
    ERROR_ISSUE_NOT_FOUND = "Issue not found"
    ERROR_NO_RESULTS_FOUND = "No results found"
    ERROR_UNAUTHORIZED = "Unauthorized - check your GitHub token"
    ERROR_SAML_PROTECTED = "This repository requires SAML SSO authorization. Please authorize your personal access token with the organization. See: https://docs.github.com/en/enterprise-cloud@latest/authentication/authenticating-with-single-sign-on/authorizing-a-personal-access-token-for-use-with-single-sign-on"
    ERROR_INVALID_TOKEN = "Invalid GitHub token"

    config_accessor :default_rate_limit_delay, default: ApiConfiguration::DEFAULT_RATE_LIMIT_DELAY
    config_accessor :max_retries, default: ApiConfiguration::MAX_RETRIES

    attr_reader :token, :domain, :client

    def initialize(token:, domain: "github.com")
      @token = token
      @domain = domain
      validate_config!
      @client = build_client
      configure_client
    end

    def fetch_repository(owner, repo_name)
      with_rate_limiting do
        repo = @client.repository("#{owner}/#{repo_name}")
        normalize_repository_data(repo)
      end
    rescue Octokit::NotFound
      { error: ERROR_REPOSITORY_NOT_FOUND }
    rescue Octokit::Unauthorized
      { error: ERROR_UNAUTHORIZED }
    rescue Octokit::SAMLProtected
      { error: ERROR_SAML_PROTECTED }
    end

    # :reek:TooManyStatements - Includes API call and error handling
    # :reek:LongParameterList - GitHub API requires owner, repo_name, state, max_issues
    # :reek:ControlParameter - max_issues controls pagination behavior for large repos
    # Fetches issues from GitHub API
    # max_issues: Limit the number of issues to fetch (for initial sync of large repos)
    #             If nil, fetches all issues with auto-pagination
    def fetch_issues(owner, repo_name, state: "all", max_issues: nil)
      with_rate_limiting do
        options = {
          state: state,
          sort: "updated",  # Sort by last updated to get most recent activity
          direction: "desc",
          per_page: max_issues || ApiConfiguration::DEFAULT_PAGE_SIZE
        }

        # Temporarily disable auto-pagination when fetching limited issues
        original_auto_paginate = @client.auto_paginate
        @client.auto_paginate = false if max_issues

        issues = @client.issues("#{owner}/#{repo_name}", options)

        # Restore auto-pagination setting
        @client.auto_paginate = original_auto_paginate if max_issues

        issues.map { |issue| normalize_issue_data(issue) }
      end
    rescue Octokit::NotFound
      { error: ERROR_REPOSITORY_NOT_FOUND }
    rescue Octokit::Unauthorized
      { error: ERROR_UNAUTHORIZED }
    rescue Octokit::SAMLProtected
      { error: ERROR_SAML_PROTECTED }
    end

    def fetch_issue(owner, repo_name, issue_number)
      with_rate_limiting do
        issue = @client.issue("#{owner}/#{repo_name}", issue_number)
        normalize_issue_data(issue)
      end
    rescue Octokit::NotFound
      { error: ERROR_ISSUE_NOT_FOUND }
    rescue Octokit::SAMLProtected
      { error: ERROR_SAML_PROTECTED }
    end

    def fetch_issue_comments(owner, repo_name, issue_number)
      with_rate_limiting do
        comments = @client.issue_comments("#{owner}/#{repo_name}", issue_number)
        comments.map { |comment| normalize_comment_data(comment) }
      end
    rescue Octokit::NotFound
      []
    rescue Octokit::SAMLProtected
      { error: ERROR_SAML_PROTECTED }
    end

    # Fetch assignable users via GraphQL
    # Returns users who can be assigned to issues in the repository
    def fetch_assignable_users(owner, repo_name)
      query = <<~GRAPHQL
        query($owner: String!, $name: String!, $first: Int!, $after: String) {
          repository(owner: $owner, name: $name) {
            assignableUsers(first: $first, after: $after) {
              pageInfo {
                hasNextPage
                endCursor
              }
              nodes {
                login
                avatarUrl
              }
            }
          }
        }
      GRAPHQL

      all_users = []
      has_next_page = true
      after_cursor = nil

      while has_next_page
        variables = {
          owner: owner,
          name: repo_name,
          first: 100,
          after: after_cursor
        }

        result = graphql_query(query, variables)

        if result[:error]
          return result
        end

        users = result.dig("data", "repository", "assignableUsers", "nodes") || []
        page_info = result.dig("data", "repository", "assignableUsers", "pageInfo") || {}

        all_users.concat(users.map { |user| normalize_assignable_user_data(user) })

        has_next_page = page_info["hasNextPage"]
        after_cursor = page_info["endCursor"]
      end

      all_users
    rescue => error
      { error: error.message }
    end

    # Search issues using GitHub's search API
    # Query syntax: https://docs.github.com/en/search-github/searching-on-github/searching-issues-and-pull-requests
    # :reek:LongParameterList - GitHub API requires these parameters
    def search_issues(query, sort: nil, order: nil, per_page: 30, page: 1)
      with_rate_limiting do
        search_options = { per_page: per_page, page: page }
        search_options[:sort] = sort if sort.present?
        search_options[:order] = order if order.present?

        # Disable auto-pagination for search to avoid fetching 500+ issues when we only need 10-30
        # This dramatically improves performance for large result sets
        original_auto_paginate = @client.auto_paginate
        @client.auto_paginate = false

        results = @client.search_issues(query, search_options)

        # Restore auto-pagination setting
        @client.auto_paginate = original_auto_paginate

        # Capture rate limit info from response headers
        @last_rate_limit = extract_rate_limit_from_headers

        # Return both the normalized items and the total count from the search API
        {
          items: results.items.map { |issue| normalize_issue_data(issue) },
          total_count: results.total_count
        }
      end
    rescue Octokit::NotFound
      { error: ERROR_NO_RESULTS_FOUND }
    rescue Octokit::Unauthorized
      { error: ERROR_UNAUTHORIZED }
    rescue Octokit::SAMLProtected
      { error: ERROR_SAML_PROTECTED }
    end

    # :reek:TooManyStatements - Includes API call and multiple rescue clauses
    # :reek:UncommunicativeVariableName - 'e' is Rails convention for exception
    def test_connection
      with_rate_limiting do
        @client.user
        { success: true }
      end
    rescue Octokit::Unauthorized
      { success: false, error: ERROR_INVALID_TOKEN }
    rescue => e
      { success: false, error: e.message }
    end

    def rate_limit_info
      # Return the rate limit info captured from the last API call
      @last_rate_limit
    end

    private

    # Execute a GraphQL query
    # :reek:UtilityFunction - Wrapper for GraphQL API calls
    def graphql_query(query, variables = {})
      with_rate_limiting do
        response = @client.post("/graphql", { query: query, variables: variables }.to_json)

        # Check for GraphQL errors
        if response[:errors]
          return { error: response[:errors].map { |err| err[:message] }.join(", ") }
        end

        response
      end
    rescue Octokit::Unauthorized
      { error: ERROR_UNAUTHORIZED }
    rescue => error
      { error: error.message }
    end

    def validate_config!
      raise ConfigurationError, "Token is required" if @token.blank?
      raise ConfigurationError, "Domain is required" if @domain.blank?
    end

    # :reek:DuplicateMethodCall - domain checked once for equality
    def build_client
      client_options = { access_token: @token }

      # Support GitHub Enterprise by setting custom API endpoint
      unless @domain == "github.com"
        client_options[:api_endpoint] = "https://#{@domain}/api/v3"
      end

      Octokit::Client.new(client_options)
    end

    def configure_client
      @client.auto_paginate = true
      @client.per_page = ApiConfiguration::DEFAULT_PAGE_SIZE
    end

    # :reek:TooManyStatements - Complex retry logic with rate limit handling
    # :reek:DuplicateMethodCall - Repeated checks are part of retry logic
    # :reek:UncommunicativeVariableName - 'e' is Rails convention for exception
    def with_rate_limiting(&block)
      retries = 0
      begin
        # Don't pre-check rate limit - it makes an extra API call to /rate_limit
        # Instead, rely on response headers (extracted after each call) and fail-fast on rate limit errors
        yield
      rescue Octokit::TooManyRequests => e
        # Don't retry on rate limit - fail fast and let controller fall back to cache
        Rails.logger.warn "Rate limited. Failing fast to allow cache fallback."
        raise
      rescue Octokit::ServerError => e
        if retries < config.max_retries
          retries += 1
          delay = ApiConfiguration::RETRY_BACKOFF_BASE ** retries
          Rails.logger.warn "Server error (#{e.message}). Retrying in #{delay}s (attempt #{retries}/#{config.max_retries})"
          sleep(delay)
          retry
        else
          raise
        end
      end
    end

    # Extract rate limit info from the last response headers
    # GitHub returns rate limit info in X-RateLimit-* headers
    def extract_rate_limit_from_headers
      return nil unless @client.last_response

      headers = @client.last_response.headers
      remaining = headers["x-ratelimit-remaining"]
      limit = headers["x-ratelimit-limit"]
      reset = headers["x-ratelimit-reset"]
      resource = headers["x-ratelimit-resource"]

      return nil unless remaining && limit && reset

      # GitHub has different resources: core (5000/hr), search (30/min), graphql, etc.
      info = {
        resource => {
          remaining: remaining.to_i,
          limit: limit.to_i,
          resets_at: Time.at(reset.to_i)
        }
      }

      info
    rescue StandardError => error
      Rails.logger.debug "Could not extract rate limit from headers: #{error.message}"
      nil
    end

    # :reek:UtilityFunction - Data transformation helper
    def normalize_repository_data(repo)
      {
        owner: repo.owner.login,
        name: repo.name,
        full_name: repo.full_name,
        description: repo.description,
        url: repo.html_url,
        open_issues_count: repo.open_issues_count
      }
    end

    # :reek:UtilityFunction - Data transformation helper
    # :reek:DuplicateMethodCall - issue.user accessed for both login and avatar
    def normalize_issue_data(issue)
      author = issue.user
      {
        number: issue.number,
        title: issue.title,
        state: issue.state,
        body: issue.body,
        author_login: author&.login,
        author_avatar_url: author&.avatar_url,
        labels: issue.labels.map { |label| { name: label.name, color: label.color } },
        assignees: issue.assignees.map { |assignee| { login: assignee.login, avatar_url: assignee.avatar_url } },
        comments_count: issue.comments,
        created_at: issue.created_at,
        updated_at: issue.updated_at
      }
    end

    # :reek:UtilityFunction - Data transformation helper
    # :reek:DuplicateMethodCall - comment.user accessed for both login and avatar
    def normalize_comment_data(comment)
      author = comment.user
      {
        github_id: comment.id,
        author_login: author&.login,
        author_avatar_url: author&.avatar_url,
        body: comment.body,
        created_at: comment.created_at,
        updated_at: comment.updated_at
      }
    end

    # :reek:UtilityFunction - Data transformation helper
    def normalize_assignable_user_data(user)
      {
        login: user["login"],
        avatar_url: user["avatarUrl"]
      }
    end
  end
end
