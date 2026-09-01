# frozen_string_literal: true

# Controller for viewing GitHub pull requests from tracked repositories
#
# GitHub models pull requests as issues, so this reuses the issue list/show
# machinery with the list scope forced to `:pulls` (an `is:pr` qualifier).
#
# On top of that it adds GitHub's two extra sub-pages, Commits and Files
# changed. Neither is cached: commit lists and diffs are large, immutable once
# a pull request is merged, and rarely revisited, so they are fetched per view
# and degraded around rather than stored.
# :reek:InstanceVariableAssumption - @repository is set by IssueListable's before_action, @issue by load_issue_record
class PullsController < ApplicationController
  include IssueListable
  include IssueShowable

  def show
    load_and_display_issue
  end

  def commits
    return unless load_issue_record

    @commits = load_tab_collection { |client, owner, name| client.fetch_pull_request_commits(owner, name, @issue.number) }
  end

  def files
    return unless load_issue_record

    @files = load_tab_collection { |client, owner, name| client.fetch_pull_request_files(owner, name, @issue.number) }
  end

  private

  def list_scope
    IssueScoped::PULLS_SCOPE
  end

  # Both tabs fetch live and fail the same way, so they share the plumbing:
  # no token or an error payload yields an empty collection plus a flash,
  # leaving the page to render its header, tabs and empty state instead of
  # blowing up.
  # :reek:TooManyStatements - Resolves a client, calls it, and sorts success from failure
  def load_tab_collection
    client = github_client
    return flash_tab_error(t("pulls.errors.no_token", domain: @repository.github_domain)) unless client

    result = yield(client, @repository.owner, @repository.name)
    error = result.is_a?(Hash) && result[:error]

    error ? flash_tab_error(error) : result
  end

  def flash_tab_error(message)
    flash.now[:alert] = message
    []
  end
end
