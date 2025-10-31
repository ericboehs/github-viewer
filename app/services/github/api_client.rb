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
      { error: "Repository not found" }
    rescue Octokit::Unauthorized
      { error: "Unauthorized - check your GitHub token" }
    end

    # :reek:TooManyStatements - Includes API call and error handling
    def fetch_issues(owner, repo_name, state: "all")
      with_rate_limiting do
        issues = @client.issues("#{owner}/#{repo_name}", state: state, per_page: ApiConfiguration::DEFAULT_PAGE_SIZE)
        issues.map { |issue| normalize_issue_data(issue) }
      end
    rescue Octokit::NotFound
      { error: "Repository not found" }
    rescue Octokit::Unauthorized
      { error: "Unauthorized - check your GitHub token" }
    end

    def fetch_issue(owner, repo_name, issue_number)
      with_rate_limiting do
        issue = @client.issue("#{owner}/#{repo_name}", issue_number)
        normalize_issue_data(issue)
      end
    rescue Octokit::NotFound
      { error: "Issue not found" }
    end

    def fetch_issue_comments(owner, repo_name, issue_number)
      with_rate_limiting do
        comments = @client.issue_comments("#{owner}/#{repo_name}", issue_number)
        comments.map { |comment| normalize_comment_data(comment) }
      end
    rescue Octokit::NotFound
      []
    end

    # Search issues using GitHub's search API
    # Query syntax: https://docs.github.com/en/search-github/searching-on-github/searching-issues-and-pull-requests
    # :reek:LongParameterList - GitHub API requires these parameters
    def search_issues(query, sort: nil, order: nil)
      with_rate_limiting do
        search_options = { per_page: ApiConfiguration::DEFAULT_PAGE_SIZE }
        search_options[:sort] = sort if sort.present?
        search_options[:order] = order if order.present?

        results = @client.search_issues(query, search_options)

        # Capture rate limit info from response headers
        @last_rate_limit = extract_rate_limit_from_headers

        results.items.map { |issue| normalize_issue_data(issue) }
      end
    rescue Octokit::NotFound
      { error: "No results found" }
    rescue Octokit::Unauthorized
      { error: "Unauthorized - check your GitHub token" }
    end

    # :reek:TooManyStatements - Includes API call and multiple rescue clauses
    # :reek:UncommunicativeVariableName - 'e' is Rails convention for exception
    def test_connection
      with_rate_limiting do
        @client.user
        { success: true }
      end
    rescue Octokit::Unauthorized
      { success: false, error: "Invalid GitHub token" }
    rescue => e
      { success: false, error: e.message }
    end

    def rate_limit_info
      # Return the rate limit info captured from the last API call
      @last_rate_limit
    end

    private

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
        check_rate_limit
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

    # :reek:TooManyStatements - Rate limit logic requires multiple checks
    # :reek:DuplicateMethodCall - Repeated calls are part of rate limit inspection
    def check_rate_limit
      rate_limit = @client.rate_limit
      return unless rate_limit

      remaining = rate_limit.remaining
      limit = rate_limit.limit || 5000

      Rails.logger.debug "Rate limit: #{remaining}/#{limit} remaining, resets at #{rate_limit.resets_at}"

      # Don't sleep on warnings - just log and let request proceed
      # This allows fast fallback to cache when rate limited
      if remaining < ApiConfiguration::CRITICAL_RATE_LIMIT_THRESHOLD
        Rails.logger.warn "Rate limit critical (#{remaining}/#{limit}). Request may be rate limited."
      elsif remaining < ApiConfiguration::WARNING_RATE_LIMIT_THRESHOLD
        Rails.logger.debug "Rate limit warning (#{remaining}/#{limit})."
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
  end
end
