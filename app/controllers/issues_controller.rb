# frozen_string_literal: true

# Controller for viewing GitHub issues from tracked repositories
# :reek:InstanceVariableAssumption - Controller sets instance variables for views
# :reek:TooManyInstanceVariables - Complex search UI requires multiple view variables
# :reek:DuplicateMethodCall - Controller actions access params and parsed data repeatedly
# :reek:RepeatedConditional - Debug mode checked in multiple actions
class IssuesController < ApplicationController
  before_action :set_repository

  # :reek:TooManyStatements - Controller action orchestrates sync, search, and pagination
  # :reek:DuplicateMethodCall - Params and results accessed for readability
  def index
    current_user = Current.user
    issues = @repository.issues
    flash_now = flash.now

    # Sync issues if cache is cold (no issues cached yet)
    # Skip initial sync for large repositories (>200 issues) - rely on on-demand fetching instead
    if issues.empty? && @repository.open_issue_count <= 200
      sync_result = Github::IssueSyncService.new(
        user: current_user,
        repository: @repository
      ).call

      if !sync_result[:success]
        flash_now[:alert] = t("issues.sync_error", error: sync_result[:error])
      end
    end

    # Default to is:issue state:open if q parameter is not present at all
    # If q is present but blank (from clicking X), show all issues
    @query = if params.has_key?(:q)
      params[:q] # Could be blank string from clicking X
    else
      "is:issue state:open" # Default for first visit
    end

    # Parse search query for GitHub qualifiers
    parsed_query = parse_search_query(@query)

    # Default to GitHub mode for fresh data, fall back to local cache on failure
    # Users can explicitly opt into local mode via params[:search_mode]
    search_mode = params[:search_mode]&.to_sym || :github

    search_result = Github::IssueSearchService.new(
      user: current_user,
      repository: @repository,
      query: parsed_query[:query],
      filters: parsed_query[:filters],
      sort_by: parsed_query[:sort] || params[:sort] || "created",
      search_mode: search_mode,
      per_page: 30,
      page: params[:page] || 1
    ).call

    if search_result[:success]
      all_results = search_result[:issues]
      @total_count = search_result[:count]  # Total count from API (for pagination)

      # For GitHub API mode, results are already paginated, so create Pagy object manually
      # For local mode, all results are returned and we paginate them
      if search_result[:mode] == :github && @total_count.present?
        @pagy = Pagy.new(count: @total_count, page: params[:page] || 1, limit: 30)
        @issues = all_results
      else
        @pagy, @issues = pagy_array(all_results, limit: 30)
      end

      @search_mode = search_result[:mode]

      # Show rate limit warning if approaching limit or if debug mode
      rate_limit = search_result[:rate_limit]
      Rails.logger.debug "Rate limit from search result: #{rate_limit.inspect}" if params[:debug] == "true"

      if rate_limit && rate_limit.any?
        if params[:debug] == "true" || approaching_rate_limit?(rate_limit)
          show_rate_limit_warning(rate_limit)
        end
      elsif params[:debug] == "true"
        flash.now[:notice] = t("issues.errors.rate_limit_unavailable")
      end
    else
      # Fall back to local cache if GitHub API fails
      local_result = Github::IssueSearchService.new(
        user: current_user,
        repository: @repository,
        query: parsed_query[:query],
        filters: parsed_query[:filters],
        sort_by: parsed_query[:sort] || params[:sort] || "created",
        search_mode: :local,
        per_page: 10
      ).call

      if local_result[:success] && local_result[:issues].any?
        all_results = local_result[:issues]
        @pagy, @issues = pagy_array(all_results, limit: 30)
        @search_mode = :local

        # Customize error message based on error type
        error_msg = search_result[:error]
        if error_msg&.include?("rate limit")
          # Rate limit error - use the message from the service which includes reset time
          flash_now[:alert] = t("issues.errors.rate_limited_showing_cached", error: error_msg)

          # Show rate limit info even when rate limited (from error response headers)
          if search_result[:rate_limit]
            show_rate_limit_warning(search_result[:rate_limit])
          end
        else
          # Other errors (connection issues, etc.)
          domain = @repository.github_domain
          flash_now[:alert] = t("issues.errors.cannot_reach_showing_cached", domain: domain, error: error_msg)
        end
      else
        all_results = issues.order(github_updated_at: :desc).to_a
        @pagy, @issues = pagy_array(all_results, limit: 30)
        flash_now[:alert] = search_result[:error]
      end
    end

    # Calculate state counts
    if parsed_query[:filters][:state].present?
      # If state filter is present, use total count from API for that state
      # and fetch the opposite state's count
      current_state = parsed_query[:filters][:state]

      if current_state == "open"
        @open_count = @total_count
        # Get closed count
        if search_result[:mode] == :github
          closed_filters = parsed_query[:filters].merge(state: "closed")
          closed_result = Github::IssueSearchService.new(
            user: current_user,
            repository: @repository,
            query: parsed_query[:query],
            filters: closed_filters,
            sort_by: parsed_query[:sort] || params[:sort] || "created",
            search_mode: :github,
            per_page: 1,
            page: 1
          ).call
          @closed_count = closed_result[:success] ? closed_result[:count] : nil
        else
          @closed_count = @repository.issues.by_state("closed").count
        end
      else # closed
        @closed_count = @total_count
        # Get open count
        if search_result[:mode] == :github
          open_filters = parsed_query[:filters].merge(state: "open")
          open_result = Github::IssueSearchService.new(
            user: current_user,
            repository: @repository,
            query: parsed_query[:query],
            filters: open_filters,
            sort_by: parsed_query[:sort] || params[:sort] || "created",
            search_mode: :github,
            per_page: 1,
            page: 1
          ).call
          @open_count = open_result[:success] ? open_result[:count] : nil
        else
          @open_count = @repository.issues.by_state("open").count
        end
      end
    else
      # No state filter - make two quick API queries to get accurate counts
      if search_result[:mode] == :github
        # Get open count
        open_filters = parsed_query[:filters].merge(state: "open")
        open_result = Github::IssueSearchService.new(
          user: current_user,
          repository: @repository,
          query: parsed_query[:query],
          filters: open_filters,
          sort_by: parsed_query[:sort] || params[:sort] || "created",
          search_mode: :github,
          per_page: 1,  # We only need the count, not the results
          page: 1
        ).call
        @open_count = open_result[:success] ? open_result[:count] : nil

        # Get closed count
        closed_filters = parsed_query[:filters].merge(state: "closed")
        closed_result = Github::IssueSearchService.new(
          user: current_user,
          repository: @repository,
          query: parsed_query[:query],
          filters: closed_filters,
          sort_by: parsed_query[:sort] || params[:sort] || "created",
          search_mode: :github,
          per_page: 1,  # We only need the count, not the results
          page: 1
        ).call
        @closed_count = closed_result[:success] ? closed_result[:count] : nil
      else
        # Local mode - count from all results
        @open_count = all_results.count { |issue| issue.state == "open" }
        @closed_count = all_results.count { |issue| issue.state == "closed" }
      end
    end

    # Extract unique labels from ALL repository issues (not just search results)
    # This ensures labels dropdown is always available regardless of filters
    @available_labels = extract_unique_labels(@repository.issues)
  end

  # :reek:TooManyStatements - Controller action orchestrates auto-refresh logic
  # :reek:NilCheck - Explicit nil check required to detect uncached issues
  def show
    @issue = @repository.issues.find_by(number: params[:id])

    # Fetch from API if issue doesn't exist in database yet (beyond initial 200)
    # Or auto-refresh if issue is stale (older than 5 minutes)
    sync_result = nil
    if @issue.nil? || @issue.cached_at.nil? || @issue.cached_at < 5.minutes.ago
      issue_number = @issue&.number || params[:id].to_i
      sync_result = Github::IssueSyncService.new(
        user: Current.user,
        repository: @repository,
        issue_number: issue_number
      ).call

      if sync_result[:success]
        # Load or reload issue after sync
        @issue = @repository.issues.find_by!(number: issue_number)
      elsif @issue.nil?
        # Issue doesn't exist and sync failed - show error
        flash[:alert] = t("issues.errors.issue_not_found", error: sync_result[:error])
        redirect_to repository_issues_path(@repository) and return
      end
    end

    # Fetch project fields and timeline (API-only, no caching)
    github_token = Current.user.github_tokens.find_by(domain: @repository.github_domain)
    if github_token
      client = Github::ApiClient.new(token: github_token.token, domain: @repository.github_domain)

      # Fetch project fields for sidebar
      @project_items = client.fetch_issue_project_fields(
        @repository.owner,
        @repository.name,
        @issue.number
      )

      # Fetch timeline events
      timeline_events = client.fetch_issue_timeline(
        @repository.owner,
        @repository.name,
        @issue.number
      )

      # Merge timeline events with cached comments and sort chronologically
      @timeline_items = merge_timeline_with_comments(timeline_events)
    else
      @project_items = []
      @timeline_items = comments_to_timeline_items(@issue.issue_comments)
    end

    # Show rate limit info if debug mode
    if params[:debug] == "true"
      rate_limit = sync_result&.[](:rate_limit)
      if rate_limit && rate_limit.any?
        show_rate_limit_warning(rate_limit)
      else
        flash.now[:notice] = t("issues.errors.rate_limit_unavailable")
      end
    end
  end

  # :reek:TooManyStatements - Controller action orchestrates sync and redirect
  def refresh
    issue_id = params[:id]
    issue_id_present = issue_id.present?

    # Determine if syncing single issue or all issues
    sync_service_params = { user: Current.user, repository: @repository }
    sync_service_params[:issue_number] = issue_id.to_i if issue_id_present

    result = Github::IssueSyncService.new(**sync_service_params).call

    # Preserve search query and debug parameter
    search_params = {}
    search_params[:q] = params[:q] if params[:q].present?
    search_params[:debug] = params[:debug] if params[:debug].present?

    # Determine redirect path based on whether this is a member or collection action
    redirect_path = if issue_id_present
      issue = @repository.issues.find_by!(number: issue_id)
      repository_issue_path(@repository, issue.number, search_params)
    else
      repository_issues_path(@repository, search_params)
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
  # Supports: is:open, is:closed, label:name (multiple), assignee:username, author:username, sort:field-direction
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

  # :reek:TooManyStatements - Calculates threshold warnings for multiple resources
  # :reek:UtilityFunction - Pure calculation function for rate limit warnings
  def approaching_rate_limit?(rate_limit)
    return false unless rate_limit

    # Check if any resource is approaching its limit
    rate_limit.each do |resource, info|
      percentage = (info[:remaining].to_f / info[:limit]) * 100

      # Different thresholds based on resource type
      threshold = case resource
      when "search"
        20 # Warn at 20% for search (30/min limit)
      else
        20 # Warn at 20% for core and other resources
      end

      return true if percentage < threshold
    end

    false
  end

  # :reek:TooManyStatements - Formats and displays rate limit for multiple resources
  # :reek:DuplicateMethodCall - Flash and message formatting accessed for readability
  def show_rate_limit_warning(rate_limit)
    return unless rate_limit

    messages = []

    # Show rate limit for each resource type
    rate_limit.each do |resource, info|
      remaining = info[:remaining]
      limit = info[:limit]
      resets_at = info[:resets_at]
      percentage = ((remaining.to_f / limit) * 100).round(1)

      # Format resource name nicely
      resource_name = resource.to_s.capitalize
      messages << "#{resource_name}: #{remaining}/#{limit} (#{percentage}%). Resets at #{resets_at.strftime('%I:%M %p')}"
    end

    # Use warning (yellow) banner when approaching limit, notice (blue) when just showing debug info
    if approaching_rate_limit?(rate_limit)
      flash.now[:warning] = t("issues.rate_limits.warning", messages: messages.join(" | "))
    else
      flash.now[:notice] = t("issues.rate_limits.notice", messages: messages.join(" | "))
    end
  end

  # Merge timeline events from API with cached comments from database
  # Returns array sorted chronologically by created_at
  # :reek:UtilityFunction - Pure data transformation helper
  def merge_timeline_with_comments(timeline_events)
    # Convert cached comments to timeline items (those not in API response)
    comment_items = comments_to_timeline_items(@issue.issue_comments)

    # Merge API timeline events with cached comments
    all_items = timeline_events + comment_items

    # Sort chronologically and remove nil values
    all_items.compact.sort_by { |item| item[:created_at] }
  end

  # Convert cached comments to timeline item format
  # :reek:UtilityFunction - Pure data transformation helper
  # :reek:FeatureEnvy - Accesses comment attributes extensively
  def comments_to_timeline_items(comments)
    comments.map do |comment|
      {
        type: "comment",
        id: "cached_#{comment.id}",
        created_at: comment.github_created_at,
        actor: comment.author_login,
        body: comment.body,
        avatar_url: comment.author_avatar_url
      }
    end
  end
end
