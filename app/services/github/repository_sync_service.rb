# frozen_string_literal: true

# Synchronizes repository data from GitHub API to local database
class Github::RepositorySyncService
  attr_reader :user, :github_domain, :owner, :repo_name

  def initialize(user:, github_domain:, owner:, repo_name:)
    @user = user
    @github_domain = github_domain
    @owner = owner
    @repo_name = repo_name
  end

  def call
    github_token = user.github_tokens.find_by(domain: github_domain)

    unless github_token
      return { success: false, error: "No GitHub token configured for #{github_domain}" }
    end

    client = Github::ApiClient.new(token: github_token.token, domain: github_domain)
    repo_data = client.fetch_repository(owner: owner, repo_name: repo_name)

    if repo_data[:error]
      { success: false, error: repo_data[:error] }
    else
      repository = upsert_repository(repo_data)
      { success: true, repository: repository }
    end
  end

  private

  # :reek:UtilityFunction - Data transformation helper
  def upsert_repository(repo_data)
    user.repositories.find_or_initialize_by(
      github_domain: github_domain,
      owner: repo_data[:owner],
      name: repo_data[:name]
    ).tap do |repo|
      repo.full_name = repo_data[:full_name]
      repo.description = repo_data[:description]
      repo.url = repo_data[:url]
      repo.issue_count = repo_data[:issue_count]
      repo.open_issue_count = repo_data[:open_issue_count]
      repo.cached_at = Time.current
      repo.save!
    end
  end
end
