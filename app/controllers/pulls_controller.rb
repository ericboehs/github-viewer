# frozen_string_literal: true

# Controller for viewing GitHub pull requests from tracked repositories
#
# GitHub models pull requests as issues, so this reuses the issue list/show
# machinery with the list scope forced to `:pulls` (an `is:pr` qualifier).
#
# On top of that it adds GitHub's two extra sub-pages, Commits and Files
# changed, plus a viewer for a single file's full contents. None is cached:
# commit lists, diffs and file bodies are large, immutable once a pull request
# is merged, and rarely revisited, so they are fetched per view and degraded
# around rather than stored.
# :reek:InstanceVariableAssumption - @repository is set by IssueListable's before_action, @issue by load_issue_record
class PullsController < ApplicationController
  include IssueListable
  include IssueShowable

  # `load_issue_record` redirects when the record is missing or is not actually
  # a pull request, which halts the callback chain for these three actions.
  before_action :load_issue_record, only: %i[commits files file]

  def show
    load_and_display_issue
  end

  def commits
    @commits = load_tab_data { |client, owner, name| client.fetch_pull_request_commits(owner, name, @issue.number) }
  end

  def files
    @files = load_tab_data { |client, owner, name| client.fetch_pull_request_files(owner, name, @issue.number) }
  end

  # Views one file's full contents at the revision under review, reached by
  # clicking a filename on the Files changed tab.
  def file
    @path = params[:path].to_s
    return redirect_to files_repository_pull_path(@repository, @issue.number) if @path.blank?

    @file = load_tab_data(fallback: nil) { |client, owner, name| fetch_file_at_head(client, owner, name) }
  end

  private

  def list_scope
    IssueScoped::PULLS_SCOPE
  end

  # The head SHA pins the file to the revision under review; fetching by branch
  # name would silently follow later pushes.
  def fetch_file_at_head(client, owner, name)
    pull = client.fetch_pull_request(owner, name, @issue.number)
    return pull if pull[:error]

    client.fetch_file_contents(owner, name, @path, ref: pull[:head_sha])
  end

  # Every tab fetches live and fails the same way, so they share the plumbing:
  # no token or an error payload yields the fallback plus a flash, leaving the
  # page to render its header, tabs and empty state instead of blowing up.
  # :reek:TooManyStatements - Resolves a client, calls it, and sorts success from failure
  def load_tab_data(fallback: [])
    client = github_client
    return flash_tab_error(t("pulls.errors.no_token", domain: @repository.github_domain), fallback) unless client

    result = yield(client, @repository.owner, @repository.name)
    error = result.is_a?(Hash) && result[:error]

    error ? flash_tab_error(error, fallback) : result
  end

  def flash_tab_error(message, fallback)
    flash.now[:alert] = message
    fallback
  end
end
