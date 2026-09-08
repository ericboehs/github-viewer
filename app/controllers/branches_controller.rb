# frozen_string_literal: true

# Lists a repository's branches, the way GitHub's Branches page does.
#
# Read live rather than cached: branches move constantly, and a stale list is
# worse than a slow one.
# :reek:InstanceVariableAssumption - Controller sets instance variables for the view
class BranchesController < ApplicationController
  include RepositoryScoped
  include LiveGithubData
  include PagedListing

  before_action :set_repository

  def index
    @page = current_page
    @branches = fetch_live(fallback: []) do |client, owner, name|
      client.fetch_branches(owner, name, page: @page, per_page: PagedListing::PAGE_SIZE)
    end
    @more_pages = @branches.size >= PagedListing::PAGE_SIZE
  end
end
