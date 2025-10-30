# frozen_string_literal: true

module Github
  # Synchronizes issues and comments from GitHub API to local database
  # Fetches all issues for a repository with labels, assignees, and comments
  # Optionally syncs a single issue when issue_number is provided
  # :reek:TooManyStatements - Service orchestrates API calls, batch upserts, and error handling
  class IssueSyncService
    attr_reader :user, :repository, :issue_number

    def initialize(user:, repository:, issue_number: nil)
      @user = user
      @repository = repository
      @issue_number = issue_number
    end

    # :reek:DuplicateMethodCall - repository.github_domain accessed for token lookup and client
    def call
      domain = repository.github_domain
      github_token = user.github_tokens.find_by(domain: domain)
      return { success: false, error: missing_token_error } unless github_token

      client = Github::ApiClient.new(token: github_token.token, domain: domain)

      # Fetch issues from GitHub API
      issues_data = if issue_number.present?
        # Fetch single issue
        single_issue = client.fetch_issue(repository.owner, repository.name, issue_number)
        single_issue.is_a?(Hash) && single_issue[:error] ? single_issue : [ single_issue ]
      else
        # Fetch all issues
        client.fetch_issues(repository.owner, repository.name, state: "all")
      end

      # Handle API errors
      if issues_data.is_a?(Hash)
        error = issues_data[:error]
        return handle_api_error(error) if error
      end

      # Sync issues and comments
      synced_count = sync_issues_with_comments(client, issues_data)

      # Update repository cache timestamp
      repository.update!(cached_at: Time.current)

      { success: true, synced_count: synced_count }
    rescue Octokit::TooManyRequests => rate_limit_error
      handle_rate_limit_error(rate_limit_error)
    rescue Octokit::Unauthorized
      handle_auth_error
    rescue StandardError => error
      handle_general_error(error)
    end

    private

    def missing_token_error
      "No GitHub token configured for #{repository.github_domain}"
    end

    # :reek:TooManyStatements - Orchestrates issue and comment syncing
    def sync_issues_with_comments(client, issues_data)
      synced_count = 0

      # Use transaction for atomicity - all issues sync or none
      ApplicationRecord.transaction do
        issues_data.each do |issue_data|
          # Upsert issue
          issue = upsert_issue(issue_data)

          # Fetch and sync comments
          sync_issue_comments(client, issue, issue_data[:number])

          synced_count += 1
        end
      end

      synced_count
    end

    # :reek:UtilityFunction - Data transformation and persistence helper
    def upsert_issue(issue_data)
      issue_attrs = issue_attributes(issue_data)

      repository.issues.find_or_initialize_by(
        number: issue_data[:number]
      ).tap do |issue|
        issue.assign_attributes(issue_attrs)
        issue.save!
      end
    end

    # :reek:UtilityFunction - Data transformation helper
    def issue_attributes(issue_data)
      {
        title: issue_data[:title],
        state: issue_data[:state],
        body: issue_data[:body],
        author_login: issue_data[:author_login],
        author_avatar_url: issue_data[:author_avatar_url],
        labels: issue_data[:labels],
        assignees: issue_data[:assignees],
        comments_count: issue_data[:comments_count],
        github_created_at: issue_data[:created_at],
        github_updated_at: issue_data[:updated_at],
        cached_at: Time.current
      }
    end

    # :reek:FeatureEnvy - issue encapsulates issue_comments relationship
    def sync_issue_comments(client, issue, issue_number)
      comments_data = client.fetch_issue_comments(repository.owner, repository.name, issue_number)

      # Handle empty or error responses
      return if comments_data.empty? || (comments_data.is_a?(Hash) && comments_data[:error])

      comments_data.each do |comment_data|
        upsert_comment(issue, comment_data)
      end
    end

    # :reek:UtilityFunction - Data transformation and persistence helper
    # :reek:FeatureEnvy - issue encapsulates issue_comments relationship
    def upsert_comment(issue, comment_data)
      comment_attrs = comment_attributes(comment_data)

      issue.issue_comments.find_or_initialize_by(
        github_id: comment_data[:github_id]
      ).tap do |comment|
        comment.assign_attributes(comment_attrs)
        comment.save!
      end
    end

    # :reek:UtilityFunction - Data transformation helper
    def comment_attributes(comment_data)
      {
        author_login: comment_data[:author_login],
        author_avatar_url: comment_data[:author_avatar_url],
        body: comment_data[:body],
        github_created_at: comment_data[:created_at],
        github_updated_at: comment_data[:updated_at]
      }
    end

    # Error handling methods

    def handle_api_error(error_message)
      Rails.logger.error "GitHub API error syncing issues for #{repository.full_name}: #{error_message}"
      { success: false, error: error_message, cache_preserved: true }
    end

    def handle_rate_limit_error(exception)
      reset_time = exception.response_headers["x-ratelimit-reset"]
      error_msg = "Rate limit exceeded. Resets at #{Time.at(reset_time.to_i)}"
      Rails.logger.warn "Rate limit syncing issues for #{repository.full_name}: #{error_msg}"
      { success: false, error: error_msg, cache_preserved: true }
    end

    def handle_auth_error
      error_msg = "Unauthorized - check your GitHub token"
      Rails.logger.error "Auth error syncing issues for #{repository.full_name}"
      { success: false, error: error_msg, cache_preserved: true }
    end

    # :reek:FeatureEnvy - exception encapsulates error details
    def handle_general_error(exception)
      message = exception.message
      error_msg = "Failed to sync issues: #{message}"
      logger = Rails.logger
      logger.error "Error syncing issues for #{repository.full_name}: #{exception.class} - #{message}"
      logger.error exception.backtrace.join("\n")
      { success: false, error: error_msg, cache_preserved: true }
    end
  end
end
