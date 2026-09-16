# frozen_string_literal: true

# The optional `(:github_domain)` segment that every GitHub-shaped URL here
# starts with.
#
# github.com is the implied host and is left out of the path, so naming it is a
# longer spelling of the same page. Serving both would give two URLs for one
# page, so the longer one redirects to the shorter.
module GithubDomainScoped
  extend ActiveSupport::Concern

  private

  def github_domain_param
    params[:github_domain].presence&.downcase || RepositoryUrls::DEFAULT_DOMAIN
  end

  def redundant_domain?
    params[:github_domain] == RepositoryUrls::DEFAULT_DOMAIN
  end

  def canonical_path
    request.original_fullpath.sub(%r{\A/#{Regexp.escape(RepositoryUrls::DEFAULT_DOMAIN)}(?=/)}, "")
  end
end
