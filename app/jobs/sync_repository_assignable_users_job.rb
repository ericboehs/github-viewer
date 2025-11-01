# frozen_string_literal: true

# Background job to sync assignable users for a repository
# Fetches assignable users from GitHub GraphQL API and stores them locally for fast search
# These users can be used for both Author and Assignee filter dropdowns
# :reek:TooManyStatements - Background job orchestrates API call, error handling, and data sync
# :reek:DuplicateMethodCall - Repository attributes accessed multiple times for logging and sync
# :reek:FeatureEnvy - Job works with repository model which is appropriate
# :reek:NestedIterators - Iterating over API results and upserting each user is necessary
class SyncRepositoryAssignableUsersJob < ApplicationJob
  queue_as :default

  def perform(repository_id)
    repository = Repository.find(repository_id)
    user = repository.user

    # Find the GitHub token for this repository's domain
    github_token = user.github_tokens.find_by(domain: repository.github_domain)
    unless github_token
      Rails.logger.error "No GitHub token found for domain #{repository.github_domain}"
      return
    end

    # Fetch assignable users from GitHub GraphQL API
    client = Github::ApiClient.new(token: github_token.token, domain: repository.github_domain)
    users_data = client.fetch_assignable_users(repository.owner, repository.name)

    # Handle API errors
    if users_data.is_a?(Hash) && users_data[:error]
      Rails.logger.error "Failed to fetch assignable users for #{repository.full_name}: #{users_data[:error]}"
      return
    end

    # Sync assignable users to database
    users_data.each do |user_data|
      login = user_data[:login]

      # Skip users with blank logins (deleted accounts, etc.)
      next if login.blank?

      # Upsert assignable user (update if exists, create if doesn't)
      repository.repository_assignable_users.find_or_create_by!(login: login) do |au|
        au.avatar_url = user_data[:avatar_url]
      end.update!(
        avatar_url: user_data[:avatar_url]
      )
    end

    Rails.logger.info "Synced #{users_data.size} assignable users for #{repository.full_name}"
  rescue StandardError => error
    Rails.logger.error "Error syncing assignable users for repository #{repository_id}: #{error.message}"
    raise
  end
end
