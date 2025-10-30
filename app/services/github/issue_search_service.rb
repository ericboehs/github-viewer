# frozen_string_literal: true

module Github
  # Dual-mode issue search service supporting both local SQLite and GitHub API search
  # Provides fast local filtering and sorting with optional full-text GitHub search
  # :reek:TooManyInstanceVariables { max_instance_variables: 6 }
  # :reek:LongParameterList - Service requires configuration parameters
  # :reek:ControlParameter - filters and sort_by are configuration, not control flow
  class IssueSearchService
    attr_reader :user, :repository, :query, :filters, :sort_by, :search_mode

    # Search modes
    LOCAL_MODE = :local
    GITHUB_MODE = :github

    # Sort options
    SORT_OPTIONS = %w[created updated comments].freeze
    DEFAULT_SORT = "updated"

    def initialize(user:, repository:, query: nil, filters: {}, sort_by: DEFAULT_SORT, search_mode: LOCAL_MODE)
      @user = user
      @repository = repository
      @query = query
      @filters = filters || {}
      @sort_by = sort_by || DEFAULT_SORT
      @search_mode = search_mode
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
      results = client.search_issues(search_query, sort: sort_params[:sort], order: sort_params[:order])

      # Handle API errors
      error = results[:error] if results.is_a?(Hash)
      return { success: false, error: error } if error

      # Sync found issues to local database
      synced_issues = sync_search_results(results)

      {
        success: true,
        issues: synced_issues,
        mode: :github,
        count: synced_issues.count
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
      label = filters[:label]
      assignee = filters[:assignee]

      issues = issues.by_state(state) if state.present?
      issues = issues.with_label(label) if label.present?
      issues = issues.assigned_to(assignee) if assignee.present?
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
      label = filters[:label]
      assignee = filters[:assignee]

      parts << "state:#{state}" if state.present?
      parts << "label:\"#{label}\"" if label.present?
      parts << "assignee:#{assignee}" if assignee.present?
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
    def sync_search_results(results)
      synced_issues = []

      results.each do |issue_data|
        issue = repository.issues.find_or_initialize_by(number: issue_data[:number])
        issue.assign_attributes(
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
          cached_at: Time.current
        )
        issue.save!
        synced_issues << issue
      end

      synced_issues
    end

    # Error handling

    def missing_token_error
      "No GitHub token configured for #{repository.github_domain}"
    end

    def handle_rate_limit_error(exception)
      reset_time = exception.response_headers["x-ratelimit-reset"]
      error_msg = "Search rate limit exceeded. Resets at #{Time.at(reset_time.to_i)}"
      Rails.logger.warn "Rate limit during search for #{repository.full_name}: #{error_msg}"
      { success: false, error: error_msg }
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
