# frozen_string_literal: true

# Synchronizes repository data from GitHub API to local database
# :reek:TooManyStatements - Service orchestrates token lookup, API call, and persistence
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
    repo_data = client.fetch_repository(owner, repo_name)

    error = repo_data[:error]
    return { success: false, error: error } if error

    repository = upsert_repository(repo_data)

    # Trigger background sync of assignable users for filter dropdowns
    SyncRepositoryAssignableUsersJob.perform_later(repository.id)

    { success: true, repository: repository }
  rescue Octokit::TooManyRequests => rate_limit_error
    handle_rate_limit_error(rate_limit_error)
  rescue Octokit::Unauthorized
    handle_auth_error
  rescue StandardError => error
    handle_general_error(error)
  end

  private

  def missing_token_error
    "No GitHub token configured for #{github_domain}"
  end

  def handle_rate_limit_error(exception)
    reset_time = exception.response_headers["x-ratelimit-reset"]
    error_msg = "Rate limit exceeded. Resets at #{Time.at(reset_time.to_i)}"
    Rails.logger.warn "Rate limit syncing repository #{owner}/#{repo_name}: #{error_msg}"
    { success: false, error: error_msg }
  end

  def handle_auth_error
    Rails.logger.error "Auth error syncing repository #{owner}/#{repo_name}"
    { success: false, error: "Unauthorized - check your GitHub token" }
  end

  # :reek:FeatureEnvy - exception encapsulates error details
  def handle_general_error(exception)
    message = exception.message
    Rails.logger.error "Error syncing repository #{owner}/#{repo_name}: #{exception.class} - #{message}"
    { success: false, error: "Failed to sync repository: #{message}" }
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
      issue_count: repo_data[:issue_count] || 0,
      open_issue_count: repo_data[:open_issues_count] || 0,  # Note: API returns open_issues_count
      cached_at: Time.current
    }
  end
end
