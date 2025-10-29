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
    return { success: false, error: missing_token_error } unless github_token

    client = Github::ApiClient.new(token: github_token.token, domain: github_domain)
    repo_data = client.fetch_repository(owner: owner, repo_name: repo_name)

    error = repo_data[:error]
    return { success: false, error: error } if error

    repository = upsert_repository(repo_data)
    { success: true, repository: repository }
  end

  private

  def missing_token_error
    "No GitHub token configured for #{github_domain}"
  end

  # :reek:UtilityFunction - Data transformation helper
  def upsert_repository(repo_data)
    repo_attrs = repository_attributes(repo_data)

    user.repositories.find_or_initialize_by(
      github_domain: github_domain,
      owner: repo_data[:owner],
      name: repo_data[:name]
    ).tap do |repo|
      repo.assign_attributes(repo_attrs)
      repo.save!
    end
  end

  # :reek:UtilityFunction
  def repository_attributes(repo_data)
    {
      full_name: repo_data[:full_name],
      description: repo_data[:description],
      url: repo_data[:url],
      issue_count: repo_data[:issue_count],
      open_issue_count: repo_data[:open_issue_count],
      cached_at: Time.current
    }
  end
end
