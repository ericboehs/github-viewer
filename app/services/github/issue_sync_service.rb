# frozen_string_literal: true

module Github
  # Synchronizes issues and comments from GitHub API to local database
  # Fetches all issues for a repository with labels, assignees, and comments
  # Optionally syncs a single issue when issue_number is provided
  # :reek:TooManyStatements - Service orchestrates API calls, batch upserts, and error handling
  # :reek:NilCheck - Explicit check for issue_number presence
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
        # Fetch most recent 200 issues for large repos
        # Additional issues will be fetched on-demand when viewed or searched
        client.fetch_issues(repository.owner, repository.name, state: "all", max_issues: 200)
      end

      # Handle API errors
      if issues_data.is_a?(Hash)
        error = issues_data[:error]
        return handle_api_error(error) if error
      end

      # Sync issues, and comments only for single-issue refreshes.
      #
      # Bulk syncs deliberately skip comment prefetching: fetching a comment
      # thread per issue means one HTTP round-trip per issue (200+ sequential
      # requests) inside a single transaction, which made list pages take
      # minutes on slower GitHub Enterprise hosts. Bulk-synced issues keep a
      # nil `cached_at`, so `IssueShowable` treats them as stale and fetches
      # the full issue plus its comments on first view instead.
      single_issue_sync = issue_number.present?
      synced_count = sync_issues_with_comments(client, issues_data, with_comments: single_issue_sync)

      # Update repository cache timestamp only when syncing all issues
      # Single issue refreshes should not update the repository timestamp
      repository.update!(cached_at: Time.current) if issue_number.nil?

      { success: true, synced_count: synced_count, rate_limit: client.rate_limit_info }
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
    # :reek:ControlParameter - with_comments selects the sync strategy
    # :reek:BooleanParameter - Bulk and single-issue syncs differ only by this flag
    def sync_issues_with_comments(client, issues_data, with_comments: true)
      synced_count = 0

      # Use transaction for atomicity - all issues sync or none
      ApplicationRecord.transaction do
        issues_data.each do |issue_data|
          # Upsert issue
          issue = upsert_issue(issue_data, cached: with_comments)

          # Fetch and sync comments
          if with_comments
            sync_issue_comments(client, issue, issue_data[:number])
            sync_pull_request_stats(client, issue)
          end

          synced_count += 1
        end
      end

      synced_count
    end

    # Diff statistics live on the pull request endpoint, not the issue one, so
    # they cost an extra request. Only single-issue refreshes pay it, and only
    # for pull requests; a failure leaves whatever we already had, since stale
    # counts on a tab beat blanking them out.
    # :reek:UtilityFunction - issue encapsulates its own persistence
    # :reek:FeatureEnvy - Reads the stats payload onto the issue, so it necessarily touches both
    def sync_pull_request_stats(client, issue)
      return unless issue.pull_request?

      stats = client.fetch_pull_request(repository.owner, repository.name, issue.number)
      return if stats.is_a?(Hash) && stats[:error]

      issue.update!(stats.slice(:commits_count, :changed_files_count, :additions, :deletions))
    end

    # :reek:UtilityFunction - Data transformation and persistence helper
    # :reek:ControlParameter - cached marks whether the record is fully hydrated
    # :reek:BooleanParameter - Hydration state is inherently a yes/no
    def upsert_issue(issue_data, cached: true)
      issue_attrs = issue_attributes(issue_data, cached: cached)

      repository.issues.find_or_initialize_by(
        number: issue_data[:number]
      ).tap do |issue|
        issue.assign_attributes(issue_attrs)
        issue.save!
      end
    end

    # `cached_at` is only stamped once an issue has been fully hydrated
    # (including its comments). Bulk syncs leave the column untouched so new
    # records keep a nil `cached_at` (signalling the show page to fetch the
    # comment thread on demand) while already-hydrated issues keep theirs.
    # :reek:UtilityFunction - Data transformation helper
    # :reek:ControlParameter - cached marks whether the record is fully hydrated
    # :reek:BooleanParameter - Hydration state is inherently a yes/no
    def issue_attributes(issue_data, cached: true)
      attributes = {
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
        pull_request: issue_data[:pull_request].present?,
        draft: issue_data[:draft].present?,
        merged_at: issue_data[:merged_at]
      }

      cached ? attributes.merge(cached_at: Time.current) : attributes
    end

    # :reek:FeatureEnvy - issue encapsulates issue_comments relationship
    def sync_issue_comments(client, issue, issue_number)
      comments_data = client.fetch_issue_comments(repository.owner, repository.name, issue_number)

      # Bail on error payloads only. An empty array is a valid "this issue has
      # no comments" answer and still has to reach the prune below, otherwise
      # deleting the last comment upstream would strand the cached copy.
      return if comments_data.is_a?(Hash) && comments_data[:error]

      synced_ids = comments_data.map do |comment_data|
        upsert_comment(issue, comment_data).github_id
      end

      prune_deleted_comments(issue, synced_ids)
    end

    # GitHub simply omits deleted comments from the list response, so anything
    # still cached under an id we did not just see has been removed upstream.
    # Without this the show page keeps rendering it forever: the timeline API
    # drops the comment too, and `merge_timeline_with_comments` treats cached
    # comments missing from the timeline as ones it needs to add back.
    # :reek:UtilityFunction - issue encapsulates issue_comments relationship
    def prune_deleted_comments(issue, synced_ids)
      stale = issue.issue_comments
      stale = stale.where.not(github_id: synced_ids) if synced_ids.any?
      stale.destroy_all
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
