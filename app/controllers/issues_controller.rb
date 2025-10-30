# frozen_string_literal: true

# Controller for viewing GitHub issues from tracked repositories
# :reek:InstanceVariableAssumption
class IssuesController < ApplicationController
  before_action :set_repository

  # :reek:TooManyStatements - Controller action orchestrates sync and search
  def index
    current_user = Current.user
    issues = @repository.issues
    flash_now = flash.now

    # Sync issues if cache is cold (no issues cached yet)
    if issues.empty?
      sync_result = Github::IssueSyncService.new(
        user: current_user,
        repository: @repository
      ).call

      if !sync_result[:success]
        flash_now[:alert] = t("issues.sync_error", error: sync_result[:error])
      end
    end

    # Parse search query for GitHub qualifiers
    parsed_query = parse_search_query(params[:q])

    # Default to local mode for fast search
    # Users can explicitly opt into GitHub mode via params[:search_mode]
    search_mode = params[:search_mode]&.to_sym || :local

    search_result = Github::IssueSearchService.new(
      user: current_user,
      repository: @repository,
      query: parsed_query[:query],
      filters: parsed_query[:filters],
      sort_by: parsed_query[:sort] || params[:sort] || "updated",
      search_mode: search_mode
    ).call

    if search_result[:success]
      @issues = search_result[:issues]
      @search_mode = search_result[:mode]
    else
      @issues = issues.order(github_updated_at: :desc)
      flash_now[:alert] = search_result[:error]
    end

    # Extract unique labels and assignees for filter dropdowns
    @available_labels = extract_unique_labels(issues)
    @available_assignees = extract_unique_assignees(issues)
  end

  def show
    @issue = @repository.issues.find_by!(number: params[:id])
  end

  # :reek:TooManyStatements - Controller action orchestrates sync and redirect
  def refresh
    issue_id = params[:id]
    issue_id_present = issue_id.present?

    # Determine if syncing single issue or all issues
    sync_service_params = { user: Current.user, repository: @repository }
    sync_service_params[:issue_number] = issue_id.to_i if issue_id_present

    result = Github::IssueSyncService.new(**sync_service_params).call

    # Preserve search query
    search_params = params[:q].present? ? { q: params[:q] } : {}

    # Determine redirect path based on whether this is a member or collection action
    redirect_path = if issue_id_present
      issue = @repository.issues.find_by!(number: issue_id)
      repository_issue_path(@repository, issue.number)
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

  def extract_unique_labels(issues)
    labels_set = Set.new
    issues.each do |issue|
      next unless issue.labels.present?
      issue.labels.each do |label|
        labels_set.add(label["name"] || label[:name])
      end
    end
    labels_set.to_a.sort
  end

  def extract_unique_assignees(issues)
    assignees_set = Set.new
    issues.each do |issue|
      next unless issue.assignees.present?
      issue.assignees.each do |assignee|
        assignees_set.add(assignee["login"] || assignee[:login])
      end
    end
    assignees_set.to_a.sort
  end

  # Parse GitHub search qualifiers from query string
  # Supports: is:open, is:closed, label:name, assignee:username, sort:field-direction
  # :reek:TooManyStatements - Parses multiple qualifier types
  def parse_search_query(query_string)
    return { query: nil, filters: {}, sort: nil, has_qualifiers: false } if query_string.blank?

    query_parts = []
    filters = {}
    sort = nil
    has_qualifiers = false

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
        # Remove surrounding quotes if present
        filters[:label] = Regexp.last_match(1).gsub(/^["']|["']$/, "")
        has_qualifiers = true
      when /^assignee:(.+)$/i
        filters[:assignee] = Regexp.last_match(1).gsub(/^["']|["']$/, "")
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

    {
      query: query_parts.join(" ").presence,
      filters: filters,
      sort: sort,
      has_qualifiers: has_qualifiers
    }
  end
end
