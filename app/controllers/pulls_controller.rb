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
  include LiveGithubData

  # `load_issue_record` redirects when the record is missing or is not actually
  # a pull request, which halts the callback chain for these three actions.
  before_action :load_issue_record, only: %i[commits files file]

  def show
    load_and_display_issue
  end

  def commits
    @commits = fetch_live(fallback: []) { |client, owner, name| client.fetch_pull_request_commits(owner, name, @issue.number) }
  end

  def files
    @files = fetch_live(fallback: []) { |client, owner, name| client.fetch_pull_request_files(owner, name, @issue.number) }
  end

  # Views one file's full contents at the revision under review, reached by
  # clicking a filename on the Files changed tab. The path is the tail of the
  # URL, exactly as GitHub spells it.
  def file
    @path = params[:path].to_s
    @file = fetch_live { |client, owner, name| fetch_file_at_head(client, owner, name) }
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
end
