# frozen_string_literal: true

# Resolves the repository named by a GitHub-shaped URL - the `(:github_domain)`,
# `:owner` and `:repo` segments described in config/routes.rb - into a
# Repository record for the signed-in user.
#
# The repository does not have to be tracked already. Pasting a link to one you
# have never opened syncs it from the API on the spot, which is the whole point
# of mirroring GitHub's paths: any GitHub URL works here by deleting the scheme
# and host.
#
# :reek:InstanceVariableAssumption - @repository is set for the including controller's views
module RepositoryScoped
  extend ActiveSupport::Concern

  private

  # Halts the callback chain by redirecting whenever the repository cannot be
  # resolved, so actions can assume @repository is present.
  def set_repository
    return redirect_to canonical_path, status: :moved_permanently if redundant_domain?

    @repository = find_repository || sync_repository
  end

  def repository_domain
    params[:github_domain].presence&.downcase || RepositoryUrls::DEFAULT_DOMAIN
  end

  # github.com is the implied host, so naming it is a longer spelling of the
  # same page. Redirect rather than serve both, to keep one URL per page.
  def redundant_domain?
    params[:github_domain] == RepositoryUrls::DEFAULT_DOMAIN
  end

  def canonical_path
    request.original_fullpath.sub(%r{\A/#{Regexp.escape(RepositoryUrls::DEFAULT_DOMAIN)}(?=/)}, "")
  end

  # GitHub treats owner and repository names as case-insensitive, and links in
  # the wild are inconsistent about it.
  def find_repository
    Current.user.repositories.where(github_domain: repository_domain)
      .where("LOWER(owner) = ? AND LOWER(name) = ?", params[:owner].downcase, params[:repo].downcase)
      .first
  end

  # :reek:TooManyStatements - Checks for a usable token, then syncs and reports failure
  def sync_repository
    user = Current.user
    domain = repository_domain
    owner, name = params[:owner], params[:repo]

    unless user.github_tokens.exists?(domain: domain)
      return redirect_to root_path, alert: t("repositories.errors.no_token", domain: domain)
    end

    result = Github::RepositorySyncService.new(
      user: user, github_domain: domain, owner: owner, repo_name: name
    ).call

    return result[:repository] if result[:success]

    redirect_to root_path,
      alert: t("repositories.errors.not_found", owner: owner, name: name, domain: domain, error: result[:error])
  end
end
