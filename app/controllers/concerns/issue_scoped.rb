# frozen_string_literal: true

# Shared path/label helpers for controllers that display GitHub issues or pull
# requests. GitHub models pull requests as issues, so the same views and
# components are reused for both; `list_scope` decides which routes are used.
#
# Controllers default to the `:issues` scope. `PullsController` overrides
# `list_scope` to `:pulls`.
#
# :reek:DataClump - (repository, options) mirrors Rails' own path helper signature
module IssueScoped
  extend ActiveSupport::Concern

  ISSUES_SCOPE = :issues
  PULLS_SCOPE = :pulls

  included do
    helper_method :list_scope, :pull_request_scope?, :default_list_query, :list_i18n_scope,
                  :list_index_path, :list_refresh_path,
                  :list_item_path, :list_item_refresh_path
  end

  private

  # Overridden by PullsController
  def list_scope
    ISSUES_SCOPE
  end

  def pull_request_scope?
    list_scope == PULLS_SCOPE
  end

  # Default search query used when no `q` param is present
  def default_list_query
    pull_request_scope? ? "is:pr state:open" : "is:issue state:open"
  end

  # Translation namespace for the current scope ("issues" or "pulls")
  def list_i18n_scope
    pull_request_scope? ? "pulls" : "issues"
  end

  def list_index_path(repository, options = {})
    if pull_request_scope?
      repository_pulls_path(repository, options)
    else
      repository_issues_path(repository, options)
    end
  end

  def list_refresh_path(repository, options = {})
    if pull_request_scope?
      refresh_repository_pulls_path(repository, options)
    else
      refresh_repository_issues_path(repository, options)
    end
  end

  def list_item_path(repository, number, options = {})
    if pull_request_scope?
      repository_pull_path(repository, number, options)
    else
      repository_issue_path(repository, number, options)
    end
  end

  def list_item_refresh_path(repository, number, options = {})
    if pull_request_scope?
      refresh_repository_pull_path(repository, number, options)
    else
      refresh_repository_issue_path(repository, number, options)
    end
  end
end
