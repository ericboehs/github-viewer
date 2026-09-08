# frozen_string_literal: true

# A ref's commit history, and a single commit with its diff — GitHub's
# `/commits/:ref` and `/commit/:sha`.
#
# Both read live. History is effectively immutable once written and rarely
# revisited, so there is nothing worth caching, and a diff is far too large to
# want to store per user.
# :reek:InstanceVariableAssumption - Controller sets instance variables for the view
# :reek:TooManyInstanceVariables - A list page and a detail page's worth between two actions
class CommitsController < ApplicationController
  include RepositoryScoped
  include LiveGithubData
  include PagedListing

  before_action :set_repository

  def index
    # No ref in the URL means the default branch, which GitHub resolves for us
    # when we send no `sha` at all.
    @ref = params[:ref].presence || @repository.default_branch
    @page = current_page
    @commits = fetch_live(fallback: []) do |client, owner, name|
      client.fetch_commits(owner, name, ref: @ref, page: @page, per_page: PagedListing::PAGE_SIZE)
    end
    @more_pages = @commits.size >= PagedListing::PAGE_SIZE
  end

  def show
    @sha = params[:sha]
    @commit = fetch_live { |client, owner, name| client.fetch_commit(owner, name, @sha) }
  end
end
