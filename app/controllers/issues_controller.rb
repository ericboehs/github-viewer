# frozen_string_literal: true

# Controller for viewing GitHub issues from tracked repositories
# :reek:InstanceVariableAssumption
class IssuesController < ApplicationController
  before_action :set_repository

  def index
    issues = @repository.issues
    # Sync issues if cache is cold (no issues cached yet)
    if issues.empty?
      sync_result = Github::IssueSyncService.new(
        user: Current.user,
        repository: @repository
      ).call

      if !sync_result[:success]
        flash.now[:alert] = t("issues.sync_error", error: sync_result[:error])
      end
    end

    @issues = issues.order(github_updated_at: :desc)
  end

  def show
    @issue = @repository.issues.find_by!(number: params[:id])
  end

  def refresh
    result = Github::IssueSyncService.new(
      user: Current.user,
      repository: @repository
    ).call

    issues_path = repository_issues_path(@repository)

    if result[:success]
      redirect_to issues_path, notice: t("issues.refresh.success", count: result[:synced_count])
    else
      redirect_to issues_path, alert: t("issues.refresh.error", error: result[:error])
    end
  end

  private

  def set_repository
    @repository = Current.user.repositories.find(params[:repository_id])
  end
end
