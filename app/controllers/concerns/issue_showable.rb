# frozen_string_literal: true

# Shared logic for displaying a single GitHub issue or pull request
# Used by controllers that need to display a single GitHub issue
# :reek:InstanceVariableAssumption - Expects @repository to be set by including controller; @issue_number is optional (falls back to params[:id])
module IssueShowable
  extend ActiveSupport::Concern

  included do
    include IssueScoped
  end

  private

  # :reek:TooManyStatements - Orchestrates sync, project fields, and timeline
  # :reek:NilCheck - Explicit nil check required to detect uncached issues
  # :reek:DuplicateMethodCall - @issue and @repository accessed for readability
  def load_and_display_issue
    issue_number = @issue_number || params[:id].to_i
    @issue = @repository.issues.find_by(number: issue_number)

    # Fetch from API if issue doesn't exist, has never been cached, or is stale
    sync_result = nil
    if @issue.nil? || @issue.cached_at.nil? || @issue.cached_at < 5.minutes.ago
      sync_result = Github::IssueSyncService.new(
        user: Current.user,
        repository: @repository,
        issue_number: issue_number
      ).call

      if sync_result[:success]
        @issue = @repository.issues.find_by!(number: issue_number)
      elsif @issue.nil?
        flash[:alert] = t("issues.errors.issue_not_found", error: sync_result[:error])
        redirect_to issue_not_found_redirect_path and return
      else
        flash.now[:alert] = "Could not refresh issue data: #{sync_result[:error]}. Showing cached version."
      end
    end

    redirect_to canonical_item_path and return if scope_mismatch?

    load_project_fields_and_timeline

    # Show rate limit info if debug mode
    show_debug_rate_limit(sync_result) if params[:debug] == "true"

    render "issues/show"
  end

  # GitHub serves issues and pull requests from separate URL spaces and 302s
  # between them. Mirror that: without this, `/pulls/12` happily renders a
  # plain issue (and `/issues/12` a merged PR) on a page that contradicts
  # itself, because `github_item_url` derives its link from the record while
  # the refresh button derives its target from the route's scope.
  #
  # Checked after the sync above so `pull_request` reflects the API, not a
  # cold cache row.
  def scope_mismatch?
    @issue.pull_request? != pull_request_scope?
  end

  def canonical_item_path
    number = @issue.number

    @issue.pull_request? ? repository_pull_path(@repository, number) : repository_issue_path(@repository, number)
  end

  # :reek:TooManyStatements - Fetches project fields and timeline from API
  # :reek:DuplicateMethodCall - @repository and @issue accessed for API calls
  def load_project_fields_and_timeline
    domain = @repository.github_domain
    github_token = Current.user.github_tokens.find_by(domain: domain)
    if github_token
      client = Github::ApiClient.new(token: github_token.token, domain: domain)
      repo_owner = @repository.owner
      repo_name = @repository.name
      number = @issue.number

      @project_items = client.fetch_issue_project_fields(repo_owner, repo_name, number)

      timeline_events = client.fetch_issue_timeline(repo_owner, repo_name, number)

      @timeline_items = merge_timeline_with_comments(timeline_events)
    else
      @project_items = []
      @timeline_items = comments_to_timeline_items(@issue.issue_comments)
    end
  end

  # Consolidate label events that occur at the same time by the same actor
  # :reek:UtilityFunction - Pure data transformation helper
  # :reek:TooManyStatements - Grouping and consolidation requires multiple steps
  # :reek:NestedIterators - Grouping requires nested iteration over events
  # :reek:DuplicateMethodCall - Event attributes and grouped data accessed for readability
  def consolidate_label_events(timeline_events)
    label_types = [ "labeled", "unlabeled" ]
    grouped = timeline_events.group_by do |event|
      next unless event[:type].in?(label_types)
      [ event[:type], event[:actor], event[:created_at].to_i ]
    end

    non_label_events = timeline_events.reject { |event| event[:type].in?(label_types) }

    # Non-label events all land under a nil key above and are handled by
    # `non_label_events`. Drop that bucket by key - `Hash#compact` only removes
    # nil *values*, so it would leave the nil-keyed group in place and re-emit
    # those events below whenever the bucket happened to hold exactly one item.
    label_groups = grouped.except(nil)
    consolidated_label_events = label_groups.filter_map do |(type, _actor, _timestamp), events|
      next if events.size == 1

      first = events.first
      {
        type: type,
        id: events.map { |event| event[:id] }.join("_"),
        created_at: first[:created_at],
        actor: first[:actor],
        labels: events.map { |event| event[:label] }
      }
    end

    single_label_events = label_groups.flat_map do |(_type, _actor, _timestamp), events|
      events if events.size == 1
    end.compact

    non_label_events + consolidated_label_events + single_label_events
  end

  # Merge timeline events from API with cached comments from database
  # :reek:UtilityFunction - Pure data transformation helper
  # :reek:TooManyStatements - Deduplication and merging requires multiple steps
  def merge_timeline_with_comments(timeline_events)
    timeline_comment_ids = timeline_events
      .select { |event| event[:type] == "comment" }
      .map { |event| event[:github_id] }
      .compact

    cached_comments = @issue.issue_comments.reject { |comment| timeline_comment_ids.include?(comment.github_id) }
    comment_items = comments_to_timeline_items(cached_comments)

    consolidated_events = consolidate_label_events(timeline_events)

    all_items = consolidated_events + comment_items
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

  def issue_not_found_redirect_path
    list_index_path(@repository)
  end

  def show_debug_rate_limit(sync_result)
    rate_limit = sync_result&.[](:rate_limit)
    if rate_limit && rate_limit.any?
      show_rate_limit_warning(rate_limit)
    else
      flash.now[:notice] = t("issues.errors.rate_limit_unavailable")
    end
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
end
