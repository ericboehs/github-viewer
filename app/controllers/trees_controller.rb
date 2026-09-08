# Browses a repository's files at a ref, the way GitHub's Code tab does.
#
# The same GitHub endpoint serves directories and files, so one action covers
# both: a directory renders a listing, a file renders its contents. Nothing is
# cached — this reads live, like the pull request tabs.
# :reek:InstanceVariableAssumption - Controller sets instance variables for the view
class TreesController < ApplicationController
  include RepositoryScoped
  include LiveGithubData

  before_action :set_repository

  def show
    @path = normalized_path
    @ref = params[:ref].presence
    @contents = load_contents
  end

  private

  # Leading and trailing slashes are easy to arrive at by hand-editing the URL
  # or following a breadcrumb, and GitHub 404s on them.
  def normalized_path
    params[:path].to_s.gsub(%r{\A/+|/+\z}, "")
  end

  # A missing token or an API error leaves the page renderable: the breadcrumb
  # and an alert, rather than an exception.
  def load_contents
    fetch_live(fallback: {}) { |client, owner, name| client.fetch_contents(owner, name, @path, ref: @ref) }
  end
end
