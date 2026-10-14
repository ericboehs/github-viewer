# frozen_string_literal: true

# Fetching that goes straight to the GitHub API rather than through the cache.
#
# Commit lists, diffs, file bodies, branches: all large, effectively immutable
# once written, and rarely revisited, so they are read per view rather than
# stored. Every one of them fails the same two ways - no token for the host, or
# an error payload from the API - and in both cases the page should still
# render its header and tabs with an explanation, rather than blow up.
#
# :reek:InstanceVariableAssumption - @repository is set by the including controller
module LiveGithubData
  extend ActiveSupport::Concern

  private

  # Yields a client plus the repository's owner and name, and returns either
  # what the block produced or `fallback` with the failure in the flash.
  def fetch_live(fallback: nil)
    fetch_from_github(fallback: fallback) { |client| yield(client, @repository.owner, @repository.name) }
  end

  # The same handling for pages that are not about a repository at all - a
  # project belongs to an organization or a user - and so have only a host to
  # find a token with.
  #
  # :reek:TooManyStatements - Resolves a client, calls it, and sorts success from failure
  def fetch_from_github(fallback: nil)
    domain = live_domain
    client = github_client
    return flash_fetch_error(t("repositories.errors.no_token", domain: domain), fallback) unless client

    result = yield(client)
    error = result.is_a?(Hash) && result[:error]

    error ? flash_fetch_error(error, fallback) : result
  end

  # Which GitHub a page is about. A repository page knows from its repository;
  # anything else overrides this.
  def live_domain
    @repository.github_domain
  end

  # Nil when the user has no token for this host, which every page above
  # degrades around rather than failing on.
  def github_client
    domain = live_domain
    github_token = Current.user.github_token_for(domain)
    return unless github_token

    Github::ApiClient.new(token: github_token.token, domain: domain)
  end

  def flash_fetch_error(message, fallback)
    flash.now[:alert] = message
    fallback
  end
end
