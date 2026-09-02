# Browses a repository's files at a ref, the way GitHub's Code tab does.
#
# The same GitHub endpoint serves directories and files, so one action covers
# both: a directory renders a listing, a file renders its contents. Nothing is
# cached — this reads live, like the pull request tabs.
# :reek:InstanceVariableAssumption - Controller sets instance variables for the view
class TreesController < ApplicationController
  before_action :set_repository

  def show
    @path = normalized_path
    @ref = params[:ref].presence
    @contents = load_contents
  end

  private

  def set_repository
    @repository = Current.user.repositories.find(params[:repository_id])
  end

  # Leading and trailing slashes are easy to arrive at by hand-editing the URL
  # or following a breadcrumb, and GitHub 404s on them.
  def normalized_path
    params[:path].to_s.gsub(%r{\A/+|/+\z}, "")
  end

  # A missing token or an API error leaves the page renderable: the breadcrumb
  # and an alert, rather than an exception.
  # :reek:TooManyStatements - Resolves a client, calls it, and sorts success from failure
  def load_contents
    client = github_client
    return flash_error(t(".no_token", domain: @repository.github_domain)) unless client

    result = client.fetch_contents(@repository.owner, @repository.name, @path, ref: @ref)
    error = result[:error]

    error ? flash_error(error) : result
  end

  def flash_error(message)
    flash.now[:alert] = message
    {}
  end

  def github_client
    domain = @repository.github_domain
    github_token = Current.user.github_token_for(domain)
    return unless github_token

    Github::ApiClient.new(token: github_token.token, domain: domain)
  end
end
