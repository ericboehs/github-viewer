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

    # Use search service for filtering and sorting
    search_result = Github::IssueSearchService.new(
      user: current_user,
      repository: @repository,
      query: params[:q],
      filters: build_filters,
      sort_by: params[:sort] || "updated",
      search_mode: params[:search_mode]&.to_sym || :local
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

    # Determine redirect path based on whether this is a member or collection action
    redirect_path = if issue_id_present
      issue = @repository.issues.find_by!(number: issue_id)
      repository_issue_path(@repository, issue.number)
    else
      repository_issues_path(@repository)
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

  def build_filters
    {
      state: params[:state],
      label: params[:label],
      assignee: params[:assignee]
    }.compact
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
end
