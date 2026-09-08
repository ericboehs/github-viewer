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
  #
  # :reek:TooManyStatements - Resolves a client, calls it, and sorts success from failure
  def fetch_live(fallback: nil)
    domain = @repository.github_domain
    client = github_client
    return flash_fetch_error(t("repositories.errors.no_token", domain: domain), fallback) unless client

    result = yield(client, @repository.owner, @repository.name)
    error = result.is_a?(Hash) && result[:error]

    error ? flash_fetch_error(error, fallback) : result
  end

  # Nil when the user has no token for this repository's host, which every
  # page above degrades around rather than failing on.
  def github_client
    domain = @repository.github_domain
    github_token = Current.user.github_token_for(domain)
    return unless github_token

    Github::ApiClient.new(token: github_token.token, domain: domain)
  end

  def flash_fetch_error(message, fallback)
    flash.now[:alert] = message
    fallback
  end
end
