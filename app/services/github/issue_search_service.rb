# frozen_string_literal: true

module Github
  # Dual-mode issue search service supporting both local SQLite and GitHub API search
  # Provides fast local filtering and sorting with optional full-text GitHub search
  # :reek:TooManyInstanceVariables { max_instance_variables: 8 }
  # :reek:LongParameterList - Service requires configuration parameters
  # :reek:ControlParameter - filters and sort_by are configuration, not control flow
  # :reek:DuplicateMethodCall - Headers and rate limit accessed for readability
  # :reek:FeatureEnvy - Methods delegate to headers for rate limit extraction
  class IssueSearchService
    attr_reader :user, :repository, :query, :filters, :sort_by, :search_mode, :per_page, :page

    # Search modes
    LOCAL_MODE = :local
    GITHUB_MODE = :github

    # Sort options
    SORT_OPTIONS = %w[created updated comments].freeze
    DEFAULT_SORT = "created"

    def initialize(user:, repository:, query: nil, filters: {}, sort_by: DEFAULT_SORT, search_mode: LOCAL_MODE, per_page: 30, page: 1)
      @user = user
      @repository = repository
      @query = query
      @filters = filters || {}
      @sort_by = sort_by || DEFAULT_SORT
      @search_mode = search_mode
      @per_page = per_page
      @page = page
    end

    # :reek:UncommunicativeVariableName - 'e' is Rails convention for exception
    def call
      case search_mode
      when LOCAL_MODE
        local_search
      when GITHUB_MODE
        github_search
      else
        { success: false, error: "Invalid search mode: #{search_mode}" }
      end
    rescue StandardError => e
      handle_error(e)
    end

    private

    def local_search
      issues = repository.issues
      issues = apply_text_filter(issues) if query.present?
      issues = apply_filters(issues)
      issues = apply_sorting(issues)

      {
        success: true,
        issues: issues,
        mode: :local,
        count: issues.count
      }
    end

    # :reek:TooManyStatements - Orchestrates GitHub API search and local sync
    # :reek:UncommunicativeVariableName - 'e' is Rails convention for exception
    def github_search
      domain = repository.github_domain
      github_token = user.github_tokens.find_by(domain: domain)
      return { success: false, error: missing_token_error } unless github_token

      client = Github::ApiClient.new(token: github_token.token, domain: domain)

      # Search using GitHub API with sort parameters
      search_query = build_github_search_query
      sort_params = parse_sort_params

      # Measure API call time
      api_start = Time.current
      results = client.search_issues(search_query, sort: sort_params[:sort], order: sort_params[:order], per_page: per_page, page: page)
      api_duration = ((Time.current - api_start) * 1000).round(1)
      Rails.logger.info "GitHub API search took #{api_duration}ms for query: #{search_query} (page: #{page}, per_page: #{per_page})"

      # Handle API errors
      error = results[:error] if results.is_a?(Hash)
      return { success: false, error: error } if error

      # Extract items and total_count from search results
      items = results[:items] || []
      total_count = results[:total_count] || items.size

      # Convert API results to Issue-like objects for display (no database sync)
      mapping_start = Time.current
      issues = items.map { |issue_data| build_issue_from_api_data(issue_data) }
      mapping_duration = ((Time.current - mapping_start) * 1000).round(1)
      Rails.logger.info "Issue mapping took #{mapping_duration}ms for #{items.size} results"

      {
        success: true,
        issues: issues,
        mode: :github,
        count: total_count,
        rate_limit: client.rate_limit_info
      }
    rescue Octokit::TooManyRequests => e
      handle_rate_limit_error(e)
    rescue Octokit::Unauthorized
      handle_auth_error
    end

    def apply_text_filter(issues)
      search_term = "%#{query}%"
      issues.where("title LIKE ? OR body LIKE ?", search_term, search_term)
    end

    # :reek:TooManyStatements - Applies multiple filter conditions
    def apply_filters(issues)
      state = filters[:state]
      labels = filters[:labels] || []
      assignee = filters[:assignee]
      author = filters[:author]

      issues = issues.by_state(state) if state.present?
      # Apply each label filter (must have all labels)
      labels.each do |label|
        issues = issues.with_label(label)
      end
      issues = issues.assigned_to(assignee) if assignee.present?
      issues = issues.authored_by(author) if author.present?
      issues
    end

    # :reek:ControlParameter - sort_by controls query ordering
    # :reek:FeatureEnvy - issues encapsulates ordering logic
    def apply_sorting(issues)
      default_order = issues.order(github_updated_at: :desc)

      case sort_by
      when "created"
        issues.order(github_created_at: :desc)
      when "updated"
        default_order
      when "comments"
        issues.order(comments_count: :desc)
      else
        default_order
      end
    end

    # :reek:TooManyStatements - Builds composite search query string
    def build_github_search_query
      parts = [ "repo:#{repository.full_name}" ]
      parts << query if query.present?

      state = filters[:state]
      labels = filters[:labels] || []
      assignee = filters[:assignee]
      author = filters[:author]

      parts << "state:#{state}" if state.present?
      # Add each label as a separate qualifier
      labels.each do |label|
        parts << "label:\"#{label}\""
      end
      parts << "assignee:#{assignee}" if assignee.present?
      parts << "author:#{author}" if author.present?
      parts.join(" ")
    end

    # Parse sort_by into GitHub API sort and order parameters
    # Examples: "updated" -> {sort: "updated", order: "desc"}
    #          "created-asc" -> {sort: "created", order: "asc"}
    def parse_sort_params
      return { sort: nil, order: nil } if sort_by.blank?

      # Parse sort-direction format (e.g., "updated-asc")
      if sort_by.include?("-")
        parts = sort_by.split("-")
        { sort: parts[0], order: parts[1] }
      else
        # Default to descending order
        { sort: sort_by, order: "desc" }
      end
    end

    # :reek:UtilityFunction - Data transformation helper
    # :reek:TooManyStatements - Maps API data to model attributes
    # :reek:FeatureEnvy - issue_data encapsulates API response structure
    # Build an Issue object from API data without persisting to database
    # This allows fast search results without database writes
    def build_issue_from_api_data(issue_data)
      Issue.new(
        repository: repository,
        number: issue_data[:number],
        title: issue_data[:title],
        state: issue_data[:state],
        body: issue_data[:body],
        author_login: issue_data[:author_login],
        author_avatar_url: issue_data[:author_avatar_url],
        labels: issue_data[:labels],
        assignees: issue_data[:assignees],
        comments_count: issue_data[:comments_count],
        github_created_at: issue_data[:created_at],
        github_updated_at: issue_data[:updated_at],
        cached_at: nil  # Not cached in database
      )
    end

    # Error handling

    def missing_token_error
      "No GitHub token configured for #{repository.github_domain}"
    end

    # :reek:TooManyStatements - Handles rate limit error with header extraction
    def handle_rate_limit_error(exception)
      headers = exception.response_headers
      reset_time = headers["x-ratelimit-reset"]
      resets_at = Time.at(reset_time.to_i)
      error_msg = "Search rate limit exceeded. Showing all cached issues. Resets at #{resets_at.strftime('%I:%M %p')}"
      Rails.logger.warn "Rate limit during search for #{repository.full_name}: #{error_msg}"

      # Extract rate limit info from error response headers to show in banner
      rate_limit_info = nil
      if headers["x-ratelimit-remaining"] && headers["x-ratelimit-limit"]
        resource = headers["x-ratelimit-resource"] || "search"
        rate_limit_info = {
          resource => {
            remaining: headers["x-ratelimit-remaining"].to_i,
            limit: headers["x-ratelimit-limit"].to_i,
            resets_at: resets_at
          }
        }
      end

      { success: false, error: error_msg, rate_limit: rate_limit_info }
    end

    def handle_auth_error
      error_msg = "Unauthorized - check your GitHub token"
      Rails.logger.error "Auth error during search for #{repository.full_name}"
      { success: false, error: error_msg }
    end

    # :reek:FeatureEnvy - exception encapsulates error details
    # :reek:TooManyStatements - Error logging requires multiple statements
    def handle_error(exception)
      message = exception.message
      error_msg = "Search failed: #{message}"
      logger = Rails.logger
      logger.error "Error searching issues for #{repository.full_name}: #{exception.class} - #{message}"
      logger.error exception.backtrace.join("\n")
      { success: false, error: error_msg }
    end
  end
end
