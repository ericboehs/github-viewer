# frozen_string_literal: true

# Shared index/refresh behaviour for listing GitHub issues and pull requests.
#
# GitHub models pull requests as issues, so `IssuesController` and
# `PullsController` share this concern and differ only by `list_scope`
# (see `IssueScoped`), which forces an `is:issue` or `is:pr` qualifier.
#
# :reek:InstanceVariableAssumption - Controllers set instance variables for views
# :reek:TooManyInstanceVariables - Complex search UI requires multiple view variables
# :reek:DuplicateMethodCall - Controller actions access params and parsed data repeatedly
# :reek:RepeatedConditional - Debug mode checked in multiple actions
module IssueListable
  extend ActiveSupport::Concern

  # Number of issues shown per page
  PER_PAGE = 30

  # Repositories larger than this skip the eager initial sync and rely on
  # on-demand fetching instead
  INITIAL_SYNC_MAX_OPEN_ISSUES = 200

  included do
    include IssueScoped

    before_action :set_repository
  end

  # :reek:TooManyStatements - Controller action orchestrates sync, search, and pagination
  # :reek:DuplicateMethodCall - Params and results accessed for readability
  def index
    sync_cold_cache

    @query = params.has_key?(:q) ? params[:q] : default_list_query
    parsed_query = parse_search_query(@query)
    filters = parsed_query[:filters]

    # The list scope always wins over whatever the user typed
    filters[:type] = pull_request_scope? ? "pr" : "issue"

    # Default to GitHub mode for fresh data, fall back to local cache on failure
    # Users can explicitly opt into local mode via params[:search_mode]
    search_mode = params[:search_mode]&.to_sym || :github
    search_result = run_search(parsed_query, search_mode: search_mode, per_page: PER_PAGE, page: params[:page] || 1)

    all_results = if search_result[:success]
      assign_successful_results(search_result)
    else
      assign_fallback_results(parsed_query, search_result)
    end

    assign_state_counts(parsed_query, search_result, all_results)

    # Extract unique labels from ALL repository issues (not just search results)
    # This ensures labels dropdown is always available regardless of filters
    @available_labels = extract_unique_labels(@repository.issues)

    render "issues/index"
  end

  # :reek:TooManyStatements - Controller action orchestrates sync and redirect
  def refresh
    issue_id = params[:id]
    issue_id_present = issue_id.present?

    sync_service_params = { user: Current.user, repository: @repository }
    sync_service_params[:issue_number] = issue_id.to_i if issue_id_present

    result = Github::IssueSyncService.new(**sync_service_params).call

    # Preserve search query and debug parameter
    search_params = {}
    search_params[:q] = params[:q] if params[:q].present?
    search_params[:debug] = params[:debug] if params[:debug].present?

    redirect_path = if issue_id_present
      issue = @repository.issues.find_by!(number: issue_id)
      list_item_path(@repository, issue.number, search_params)
    else
      list_index_path(@repository, search_params)
    end

    if result[:success]
      redirect_to redirect_path, notice: t("issues.refresh.success", count: result[:synced_count])
    else
      redirect_to redirect_path, alert: t("issues.refresh.error", error: result[:error])
    end
  end

  private

  def set_repository
    @repository = Current.user.repositories.find(params[:repository_id])
  end

  # Sync issues if cache is cold (no issues cached yet)
  # :reek:TooManyStatements - Sync orchestration with error reporting
  def sync_cold_cache
    issues = @repository.issues
    return unless issues.empty? && @repository.open_issue_count <= INITIAL_SYNC_MAX_OPEN_ISSUES

    sync_result = Github::IssueSyncService.new(user: Current.user, repository: @repository).call
    return if sync_result[:success]

    flash.now[:alert] = t("issues.sync_error", error: sync_result[:error])
  end

  # :reek:LongParameterList - Mirrors the search service configuration
  # :reek:ControlParameter - filters overrides the parsed defaults for count queries
  # :reek:FeatureEnvy - parsed_query is a plain data hash built by parse_search_query
  def run_search(parsed_query, search_mode:, per_page:, page: 1, filters: nil)
    Github::IssueSearchService.new(
      user: Current.user,
      repository: @repository,
      query: parsed_query[:query],
      filters: filters || parsed_query[:filters],
      sort_by: parsed_query[:sort] || params[:sort] || "created",
      search_mode: search_mode,
      per_page: per_page,
      page: page
    ).call
  end

  # :reek:TooManyStatements - Assigns pagination, mode, and rate limit state
  # :reek:DuplicateMethodCall - Search result keys accessed for readability
  def assign_successful_results(search_result)
    all_results = search_result[:issues]
    @total_count = search_result[:count] # Total count from API (for pagination)

    # For GitHub API mode, results are already paginated, so create Pagy object manually
    # For local mode, all results are returned and we paginate them
    if search_result[:mode] == :github && @total_count.present?
      @pagy = Pagy.new(count: @total_count, page: params[:page] || 1, limit: PER_PAGE)
      @issues = all_results
    else
      @pagy, @issues = pagy_array(all_results, limit: PER_PAGE)
    end

    @search_mode = search_result[:mode]

    report_rate_limit(search_result[:rate_limit])

    all_results
  end

  # :reek:TooManyStatements - Rate limit reporting has several display branches
  def report_rate_limit(rate_limit)
    debug = params[:debug] == "true"
    Rails.logger.debug "Rate limit from search result: #{rate_limit.inspect}" if debug

    if rate_limit && rate_limit.any?
      show_rate_limit_warning(rate_limit) if debug || approaching_rate_limit?(rate_limit)
    elsif debug
      flash.now[:notice] = t("issues.errors.rate_limit_unavailable")
    end
  end

  # Fall back to local cache if GitHub API fails
  # :reek:TooManyStatements - Fallback path needs local search plus messaging
  # :reek:DuplicateMethodCall - Search results accessed for readability
  def assign_fallback_results(parsed_query, search_result)
    local_result = run_search(parsed_query, search_mode: :local, per_page: 10)

    if local_result[:success] && local_result[:issues].any?
      all_results = local_result[:issues]
      @pagy, @issues = pagy_array(all_results, limit: PER_PAGE)
      @search_mode = :local
      report_search_failure(search_result)
      all_results
    else
      all_results = @repository.issues.of_type(parsed_query.dig(:filters, :type)).order(github_updated_at: :desc).to_a
      @pagy, @issues = pagy_array(all_results, limit: PER_PAGE)
      flash.now[:alert] = search_result[:error]
      all_results
    end
  end

  # :reek:TooManyStatements - Error message differs by failure type
  def report_search_failure(search_result)
    error_msg = search_result[:error]

    if error_msg&.include?("rate limit")
      # Rate limit error - use the message from the service which includes reset time
      flash.now[:alert] = t("issues.errors.rate_limited_showing_cached", error: error_msg)

      # Show rate limit info even when rate limited (from error response headers)
      rate_limit = search_result[:rate_limit]
      show_rate_limit_warning(rate_limit) if rate_limit
    else
      # Other errors (connection issues, etc.)
      flash.now[:alert] = t("issues.errors.cannot_reach_showing_cached", domain: @repository.github_domain, error: error_msg)
    end
  end

  # :reek:TooManyStatements - Counts require conditional API queries per state
  # :reek:DuplicateMethodCall - Filters and results accessed for readability
  def assign_state_counts(parsed_query, search_result, all_results)
    filters = parsed_query[:filters]
    current_state = filters[:state]
    github_mode = search_result[:mode] == :github

    if current_state.present?
      other_state = current_state == "open" ? "closed" : "open"
      counts = { current_state => @total_count, other_state => state_count(parsed_query, other_state, github_mode) }
    else
      counts = {
        "open" => state_count(parsed_query, "open", github_mode, all_results),
        "closed" => state_count(parsed_query, "closed", github_mode, all_results)
      }
    end

    @open_count = counts["open"]
    @closed_count = counts["closed"]
  end

  # :reek:LongParameterList - Count lookup needs query, state, and mode context
  # :reek:ControlParameter - github_mode selects the counting strategy
  # :reek:TooManyStatements - Counting differs per search mode
  def state_count(parsed_query, state, github_mode, local_results = nil)
    unless github_mode
      return local_results.count { |issue| issue.state == state } if local_results
      return @repository.issues.of_type(parsed_query.dig(:filters, :type)).by_state(state).count
    end

    filters = parsed_query[:filters].merge(state: state)
    result = run_search(parsed_query, search_mode: :github, per_page: 1, page: 1, filters: filters)
    result[:success] ? result[:count] : nil
  end

  # :reek:NestedIterators - Extracting labels from issues requires nested iteration
  # :reek:TooManyStatements - Building labels list requires multiple operations
  # :reek:UtilityFunction - Pure data transformation for filter dropdowns
  # :reek:DuplicateMethodCall - Accessing label hash keys for readability
  def extract_unique_labels(issues)
    labels_hash = {}
    issues.each do |issue|
      next unless issue.labels.present?
      issue.labels.each do |label|
        name = label["name"] || label[:name]
        labels_hash[name] ||= label
      end
    end
    labels_hash.values.sort_by { |label| label["name"] || label[:name] }
  end

  # Parse GitHub search qualifiers from query string
  # Supports: is:open, is:closed, is:pr, is:issue, label:name (multiple),
  #           assignee:username, author:username, sort:field-direction
  # :reek:TooManyStatements - Parses multiple qualifier types
  # :reek:UtilityFunction - Pure parser function for search syntax
  # :reek:DuplicateMethodCall - Regexp matches accessed for readability
  def parse_search_query(query_string)
    return { query: nil, filters: {}, sort: nil, has_qualifiers: false } if query_string.blank?

    query_parts = []
    filters = {}
    sort = nil
    has_qualifiers = false
    labels = [] # Support multiple labels

    # Split query into tokens, preserving quoted strings
    tokens = query_string.scan(/(?:"[^"]*"|[^\s"])+/)

    tokens.each do |token|
      case token
      when /^is:(open|closed)$/i
        filters[:state] = Regexp.last_match(1).downcase
        has_qualifiers = true
      when /^state:(open|closed)$/i
        filters[:state] = Regexp.last_match(1).downcase
        has_qualifiers = true
      when /^(?:is|type):(pr|pull-request|issue)$/i
        filters[:type] = Regexp.last_match(1).downcase == "issue" ? "issue" : "pr"
        has_qualifiers = true
      when /^label:(.+)$/i
        # Remove surrounding quotes if present and collect multiple labels
        labels << Regexp.last_match(1).gsub(/^["']|["']$/, "")
        has_qualifiers = true
      when /^assignee:(.+)$/i
        filters[:assignee] = Regexp.last_match(1).gsub(/^["']|["']$/, "")
        has_qualifiers = true
      when /^author:(.+)$/i
        filters[:author] = Regexp.last_match(1).gsub(/^["']|["']$/, "")
        has_qualifiers = true
      when /^sort:(created|updated|comments)(?:-(asc|desc))?$/i
        # Parse sort field and direction (default to desc if not specified)
        field = Regexp.last_match(1).downcase
        direction = Regexp.last_match(2)&.downcase || "desc"
        sort = direction == "asc" ? "#{field}-asc" : field
        has_qualifiers = true
      else
        # Not a qualifier, add to search query
        query_parts << token
      end
    end

    filters[:labels] = labels if labels.any?

    {
      query: query_parts.join(" ").presence,
      filters: filters,
      sort: sort,
      has_qualifiers: has_qualifiers
    }
  end
end
