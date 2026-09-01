# frozen_string_literal: true

module Github
  # GitHub API client with token-based authentication, rate limiting, and retries
  # :reek:TooManyStatements - Complex API client with rate limiting and error handling
  # :reek:DataClump - owner/repo_name are GitHub's standard repository identifiers
  # :reek:MissingSafeMethod - validate_config! raises by design for invalid config
  # :reek:TooManyMethods - API client provides comprehensive GitHub API access
  # :reek:InstanceVariableAssumption - Client caches rate limit data
  # :reek:DuplicateMethodCall - Client response accessed for readability
  # :reek:FeatureEnvy - Methods delegate to rate_limit and headers objects
  # :reek:TooManyConstants - Error message constants grouped for clarity
  # :reek:RepeatedConditional - result[:error] checked in different GraphQL handlers
  class ApiClient
    include ActiveSupport::Configurable

    # Error raised when client configuration is invalid
    class ConfigurationError < StandardError; end
    # Error raised when GitHub authentication fails
    class AuthenticationError < StandardError; end

    # Error message constants
    ERROR_REPOSITORY_NOT_FOUND = "Repository not found"
    ERROR_ISSUE_NOT_FOUND = "Issue not found"
    ERROR_NO_RESULTS_FOUND = "No results found"
    ERROR_UNAUTHORIZED = "Unauthorized - check your GitHub token"
    ERROR_SAML_PROTECTED = "This repository requires SAML SSO authorization. Please authorize your personal access token with the organization. See: https://docs.github.com/en/enterprise-cloud@latest/authentication/authenticating-with-single-sign-on/authorizing-a-personal-access-token-for-use-with-single-sign-on"
    ERROR_INVALID_TOKEN = "Invalid GitHub token"
    ERROR_FILE_NOT_FOUND = "File not found"
    # GitHub's contents endpoint refuses to inline blobs over 1 MB and answers
    # with a 403 rather than a size field, so this is a distinct failure mode
    # from a missing file.
    ERROR_FILE_TOO_LARGE = "File is too large to display"

    config_accessor :default_rate_limit_delay, default: ApiConfiguration::DEFAULT_RATE_LIMIT_DELAY
    config_accessor :max_retries, default: ApiConfiguration::MAX_RETRIES

    attr_reader :token, :domain, :client

    def initialize(token:, domain: "github.com")
      @token = token
      @domain = domain
      validate_config!
      @client = build_client
      configure_client
    end

    def fetch_repository(owner, repo_name)
      with_rate_limiting do
        repo = @client.repository("#{owner}/#{repo_name}")
        normalize_repository_data(repo)
      end
    rescue Octokit::NotFound
      { error: ERROR_REPOSITORY_NOT_FOUND }
    rescue Octokit::Unauthorized
      { error: ERROR_UNAUTHORIZED }
    rescue Octokit::SAMLProtected
      { error: ERROR_SAML_PROTECTED }
    end

    # :reek:TooManyStatements - Includes API call and error handling
    # :reek:LongParameterList - GitHub API requires owner, repo_name, state, max_issues
    # :reek:ControlParameter - max_issues controls pagination behavior for large repos
    # Fetches issues from GitHub API
    # max_issues: Limit the number of issues to fetch (for initial sync of large repos)
    #             If nil, fetches all issues with auto-pagination
    def fetch_issues(owner, repo_name, state: "all", max_issues: nil)
      with_rate_limiting do
        options = {
          state: state,
          sort: "updated",  # Sort by last updated to get most recent activity
          direction: "desc",
          per_page: max_issues || ApiConfiguration::DEFAULT_PAGE_SIZE
        }

        # Temporarily disable auto-pagination when fetching limited issues
        original_auto_paginate = @client.auto_paginate
        @client.auto_paginate = false if max_issues

        issues = @client.issues("#{owner}/#{repo_name}", options)

        # Restore auto-pagination setting
        @client.auto_paginate = original_auto_paginate if max_issues

        issues.map { |issue| normalize_issue_data(issue) }
      end
    rescue Octokit::NotFound
      { error: ERROR_REPOSITORY_NOT_FOUND }
    rescue Octokit::Unauthorized
      { error: ERROR_UNAUTHORIZED }
    rescue Octokit::SAMLProtected
      { error: ERROR_SAML_PROTECTED }
    end

    def fetch_issue(owner, repo_name, issue_number)
      with_rate_limiting do
        issue = @client.issue("#{owner}/#{repo_name}", issue_number)
        normalize_issue_data(issue)
      end
    rescue Octokit::NotFound
      { error: ERROR_ISSUE_NOT_FOUND }
    rescue Octokit::SAMLProtected
      { error: ERROR_SAML_PROTECTED }
    end

    def fetch_issue_comments(owner, repo_name, issue_number)
      with_rate_limiting do
        comments = @client.issue_comments("#{owner}/#{repo_name}", issue_number)
        comments.map { |comment| normalize_comment_data(comment) }
      end
    rescue Octokit::NotFound
      # Must not be `[]`. Callers prune their cached comments against this
      # response, and a 404 here means we learned nothing about the thread
      # (token scope lost, repo renamed, issue converted to a discussion) --
      # not that the thread is empty. Returning an empty array would let the
      # prune delete every cached comment. `fetch_issue` reports the same
      # exception the same way.
      { error: ERROR_ISSUE_NOT_FOUND }
    rescue Octokit::SAMLProtected
      { error: ERROR_SAML_PROTECTED }
    end

    # Pull request specific metadata: diff statistics and merge state. These
    # live on the pull request endpoint rather than the issue endpoint, which is
    # why they need a separate call even though we already have the issue.
    def fetch_pull_request(owner, repo_name, number)
      with_rate_limiting do
        normalize_pull_request_data(@client.pull_request("#{owner}/#{repo_name}", number))
      end
    rescue Octokit::NotFound
      { error: ERROR_ISSUE_NOT_FOUND }
    rescue Octokit::SAMLProtected
      { error: ERROR_SAML_PROTECTED }
    end

    def fetch_pull_request_commits(owner, repo_name, number)
      with_rate_limiting do
        commits = @client.pull_request_commits("#{owner}/#{repo_name}", number)
        commits.map { |commit| normalize_commit_data(commit) }
      end
    rescue Octokit::NotFound
      { error: ERROR_ISSUE_NOT_FOUND }
    rescue Octokit::SAMLProtected
      { error: ERROR_SAML_PROTECTED }
    end

    # GitHub caps this endpoint at 300 files and omits `patch` for binary files
    # and for any diff it considers too large, so callers must treat a missing
    # patch as normal rather than as an error.
    def fetch_pull_request_files(owner, repo_name, number)
      with_rate_limiting do
        files = @client.pull_request_files("#{owner}/#{repo_name}", number)
        files.map { |file| normalize_pull_request_file_data(file) }
      end
    rescue Octokit::NotFound
      { error: ERROR_ISSUE_NOT_FOUND }
    rescue Octokit::SAMLProtected
      { error: ERROR_SAML_PROTECTED }
    end

    # Reads one file at a specific revision. `ref` should be a commit SHA
    # rather than a branch name so the content matches the revision under
    # review even after later pushes.
    # :reek:LongParameterList - Mirrors the owner/repo/... shape of the other fetches, plus the revision to read at
    def fetch_file_contents(owner, repo_name, path, ref:)
      with_rate_limiting do
        normalize_file_contents(@client.contents("#{owner}/#{repo_name}", path: path, ref: ref))
      end
    rescue Octokit::NotFound
      { error: ERROR_FILE_NOT_FOUND }
    rescue Octokit::Forbidden
      { error: ERROR_FILE_TOO_LARGE }
    rescue Octokit::SAMLProtected
      { error: ERROR_SAML_PROTECTED }
    end

    def fetch_labels(owner, repo_name)
      with_rate_limiting do
        @client.labels("#{owner}/#{repo_name}", per_page: 100)
      end
    rescue Octokit::NotFound
      []
    rescue Octokit::Unauthorized
      { error: ERROR_UNAUTHORIZED }
    rescue Octokit::SAMLProtected
      { error: ERROR_SAML_PROTECTED }
    end

    # Fetch project memberships and field values for an issue or pull request via GraphQL
    # Returns array of project items with fields like Status, Sprint, Priority, Estimate, etc.
    # Returns empty array on error (graceful degradation)
    def fetch_issue_project_fields(owner, repo_name, issue_number)
      query = <<~GRAPHQL
        fragment ProjectItemFields on ProjectV2ItemConnection {
          nodes {
            id
            project {
              title
              number
              url
            }
            fieldValues(first: 20) {
              nodes {
                __typename
                ... on ProjectV2ItemFieldSingleSelectValue {
                  name
                  field {
                    ... on ProjectV2SingleSelectField {
                      name
                    }
                  }
                }
                ... on ProjectV2ItemFieldTextValue {
                  text
                  field {
                    ... on ProjectV2Field {
                      name
                    }
                  }
                }
                ... on ProjectV2ItemFieldNumberValue {
                  number
                  field {
                    ... on ProjectV2Field {
                      name
                    }
                  }
                }
                ... on ProjectV2ItemFieldDateValue {
                  date
                  field {
                    ... on ProjectV2Field {
                      name
                    }
                  }
                }
                ... on ProjectV2ItemFieldIterationValue {
                  title
                  field {
                    ... on ProjectV2IterationField {
                      name
                    }
                  }
                }
              }
            }
          }
        }

        query($owner: String!, $name: String!, $number: Int!) {
          repository(owner: $owner, name: $name) {
            issueOrPullRequest(number: $number) {
              ... on Issue {
                projectItems(first: 10) {
                  ...ProjectItemFields
                }
              }
              ... on PullRequest {
                projectItems(first: 10) {
                  ...ProjectItemFields
                }
              }
            }
          }
        }
      GRAPHQL

      variables = { owner: owner, name: repo_name, number: issue_number }
      result = graphql_query(query, variables)

      return [] if result[:error]

      project_items = result.dig(:data, :repository, :issueOrPullRequest, :projectItems, :nodes) || []
      project_items.map { |item| normalize_project_item_data(item) }
    rescue => error
      Rails.logger.debug "Failed to fetch project fields: #{error.message}"
      []
    end

    # Fetch timeline items (events + comments) for an issue or pull request via GraphQL
    # Returns array of timeline items including labels, milestones, project events, status changes, and comments
    # Returns empty array on error (graceful degradation)
    # :reek:TooManyStatements - Complex GraphQL query with multiple event types
    def fetch_issue_timeline(owner, repo_name, issue_number)
      query = <<~GRAPHQL
        fragment TimelineEventFields on Node {
          __typename
          ... on LabeledEvent {
            id
            createdAt
            actor {
              login
            }
            label {
              name
              color
            }
          }
          ... on UnlabeledEvent {
            id
            createdAt
            actor {
              login
            }
            label {
              name
              color
            }
          }
          ... on MilestonedEvent {
            id
            createdAt
            actor {
              login
            }
            milestoneTitle
          }
          ... on DemilestonedEvent {
            id
            createdAt
            actor {
              login
            }
            milestoneTitle
          }
          ... on AddedToProjectV2Event {
            id
            createdAt
            actor {
              login
            }
            project {
              title
              number
            }
          }
          ... on RemovedFromProjectV2Event {
            id
            createdAt
            actor {
              login
            }
            project {
              title
            }
          }
          ... on ProjectV2ItemStatusChangedEvent {
            id
            createdAt
            actor {
              login
            }
            previousStatus
            status
            wasAutomated
            project {
              title
            }
          }
          ... on IssueComment {
            id
            databaseId
            createdAt
            author {
              login
              avatarUrl
            }
            body
            authorAssociation
          }
          ... on MergedEvent {
            id
            createdAt
            actor {
              login
            }
            mergeRefName
          }
          ... on ReadyForReviewEvent {
            id
            createdAt
            actor {
              login
            }
          }
          ... on ReviewRequestedEvent {
            id
            createdAt
            actor {
              login
            }
            requestedReviewer {
              ... on User {
                login
              }
              ... on Team {
                name
              }
            }
          }
          ... on PullRequestReview {
            id
            createdAt
            state
            author {
              login
              avatarUrl
            }
            body
            comments(first: 50) {
              totalCount
              nodes {
                id
                body
                path
                diffHunk
                outdated
                line
                originalLine
                createdAt
                author {
                  login
                  avatarUrl
                }
              }
            }
          }
        }

        query($owner: String!, $name: String!, $number: Int!) {
          repository(owner: $owner, name: $name) {
            issueOrPullRequest(number: $number) {
              ... on Issue {
                timelineItems(first: 100, itemTypes: [
                  LABELED_EVENT,
                  UNLABELED_EVENT,
                  MILESTONED_EVENT,
                  DEMILESTONED_EVENT,
                  ADDED_TO_PROJECT_V2_EVENT,
                  REMOVED_FROM_PROJECT_V2_EVENT,
                  PROJECT_V2_ITEM_STATUS_CHANGED_EVENT,
                  ISSUE_COMMENT
                ]) {
                  nodes {
                    ...TimelineEventFields
                  }
                }
              }
              ... on PullRequest {
                timelineItems(first: 100, itemTypes: [
                  LABELED_EVENT,
                  UNLABELED_EVENT,
                  MILESTONED_EVENT,
                  DEMILESTONED_EVENT,
                  ADDED_TO_PROJECT_V2_EVENT,
                  REMOVED_FROM_PROJECT_V2_EVENT,
                  PROJECT_V2_ITEM_STATUS_CHANGED_EVENT,
                  ISSUE_COMMENT,
                  MERGED_EVENT,
                  READY_FOR_REVIEW_EVENT,
                  REVIEW_REQUESTED_EVENT,
                  PULL_REQUEST_REVIEW
                ]) {
                  nodes {
                    ...TimelineEventFields
                  }
                }
              }
            }
          }
        }
      GRAPHQL

      variables = { owner: owner, name: repo_name, number: issue_number }
      result = graphql_query(query, variables)

      return [] if result[:error]

      timeline_items = result.dig(:data, :repository, :issueOrPullRequest, :timelineItems, :nodes) || []
      timeline_items.map { |item| normalize_timeline_item_data(item) }.compact
    rescue => error
      Rails.logger.debug "Failed to fetch timeline: #{error.message}"
      []
    end

    # Fetch assignable users via GraphQL
    # Returns users who can be assigned to issues in the repository
    def fetch_assignable_users(owner, repo_name)
      query = <<~GRAPHQL
        query($owner: String!, $name: String!, $first: Int!, $after: String) {
          repository(owner: $owner, name: $name) {
            assignableUsers(first: $first, after: $after) {
              pageInfo {
                hasNextPage
                endCursor
              }
              nodes {
                login
                avatarUrl
              }
            }
          }
        }
      GRAPHQL

      all_users = []
      has_next_page = true
      after_cursor = nil

      while has_next_page
        variables = {
          owner: owner,
          name: repo_name,
          first: 100,
          after: after_cursor
        }

        result = graphql_query(query, variables)

        if result[:error]
          return result
        end

        users = result.dig(:data, :repository, :assignableUsers, :nodes) || []
        page_info = result.dig(:data, :repository, :assignableUsers, :pageInfo) || {}

        all_users.concat(users.map { |user| normalize_assignable_user_data(user) })

        has_next_page = page_info[:hasNextPage]
        after_cursor = page_info[:endCursor]
      end

      all_users
    rescue => error
      { error: error.message }
    end

    # Search issues using GitHub's search API
    # Query syntax: https://docs.github.com/en/search-github/searching-on-github/searching-issues-and-pull-requests
    # :reek:LongParameterList - GitHub API requires these parameters
    def search_issues(query, sort: nil, order: nil, per_page: 30, page: 1)
      with_rate_limiting do
        search_options = { per_page: per_page, page: page }
        search_options[:sort] = sort if sort.present?
        search_options[:order] = order if order.present?

        # Disable auto-pagination for search to avoid fetching 500+ issues when we only need 10-30
        # This dramatically improves performance for large result sets
        original_auto_paginate = @client.auto_paginate
        @client.auto_paginate = false

        results = @client.search_issues(query, search_options)

        # Restore auto-pagination setting
        @client.auto_paginate = original_auto_paginate

        # Capture rate limit info from response headers
        @last_rate_limit = extract_rate_limit_from_headers

        # Return both the normalized items and the total count from the search API
        {
          items: results.items.map { |issue| normalize_issue_data(issue) },
          total_count: results.total_count
        }
      end
    rescue Octokit::NotFound
      { error: ERROR_NO_RESULTS_FOUND }
    rescue Octokit::Unauthorized
      { error: ERROR_UNAUTHORIZED }
    rescue Octokit::SAMLProtected
      { error: ERROR_SAML_PROTECTED }
    end

    # :reek:TooManyStatements - Includes API call and multiple rescue clauses
    # :reek:UncommunicativeVariableName - 'e' is Rails convention for exception
    def test_connection
      with_rate_limiting do
        @client.user
        { success: true }
      end
    rescue Octokit::Unauthorized
      { success: false, error: ERROR_INVALID_TOKEN }
    rescue => e
      { success: false, error: e.message }
    end

    def rate_limit_info
      # Return the rate limit info captured from the last API call
      @last_rate_limit
    end

    private

    # Execute a GraphQL query
    # :reek:UtilityFunction - Wrapper for GraphQL API calls
    def graphql_query(query, variables = {})
      with_rate_limiting do
        # GHE uses /api/graphql, GitHub.com uses /graphql
        graphql_path = @domain == "github.com" ? "/graphql" : "/api/graphql"
        response = @client.post(graphql_path, { query: query, variables: variables }.to_json)

        # Check for GraphQL errors
        if response[:errors]
          return { error: response[:errors].map { |err| err[:message] }.join(", ") }
        end

        response
      end
    rescue Octokit::Unauthorized
      { error: ERROR_UNAUTHORIZED }
    rescue => error
      { error: error.message }
    end

    def validate_config!
      raise ConfigurationError, "Token is required" if @token.blank?
      raise ConfigurationError, "Domain is required" if @domain.blank?
    end

    # :reek:DuplicateMethodCall - domain checked once for equality
    def build_client
      client_options = { access_token: @token }

      # Support GitHub Enterprise by setting custom API endpoint
      unless @domain == "github.com"
        client_options[:api_endpoint] = "https://#{@domain}/api/v3"
      end

      Octokit::Client.new(client_options)
    end

    def configure_client
      @client.auto_paginate = true
      @client.per_page = ApiConfiguration::DEFAULT_PAGE_SIZE
    end

    # :reek:TooManyStatements - Complex retry logic with rate limit handling
    # :reek:DuplicateMethodCall - Repeated checks are part of retry logic
    # :reek:UncommunicativeVariableName - 'e' is Rails convention for exception
    def with_rate_limiting(&block)
      retries = 0
      begin
        # Don't pre-check rate limit - it makes an extra API call to /rate_limit
        # Instead, rely on response headers (extracted after each call) and fail-fast on rate limit errors
        yield
      rescue Octokit::TooManyRequests => e
        # Don't retry on rate limit - fail fast and let controller fall back to cache
        Rails.logger.warn "Rate limited. Failing fast to allow cache fallback."
        raise
      rescue Octokit::ServerError => e
        if retries < config.max_retries
          retries += 1
          delay = ApiConfiguration::RETRY_BACKOFF_BASE ** retries
          Rails.logger.warn "Server error (#{e.message}). Retrying in #{delay}s (attempt #{retries}/#{config.max_retries})"
          sleep(delay)
          retry
        else
          raise
        end
      end
    end

    # Extract rate limit info from the last response headers
    # GitHub returns rate limit info in X-RateLimit-* headers
    def extract_rate_limit_from_headers
      return nil unless @client.last_response

      headers = @client.last_response.headers
      remaining = headers["x-ratelimit-remaining"]
      limit = headers["x-ratelimit-limit"]
      reset = headers["x-ratelimit-reset"]
      resource = headers["x-ratelimit-resource"]

      return nil unless remaining && limit && reset

      # GitHub has different resources: core (5000/hr), search (30/min), graphql, etc.
      info = {
        resource => {
          remaining: remaining.to_i,
          limit: limit.to_i,
          resets_at: Time.at(reset.to_i)
        }
      }

      info
    rescue StandardError => error
      Rails.logger.debug "Could not extract rate limit from headers: #{error.message}"
      nil
    end

    # :reek:UtilityFunction - Data transformation helper
    def normalize_repository_data(repo)
      {
        owner: repo.owner.login,
        name: repo.name,
        full_name: repo.full_name,
        description: repo.description,
        url: repo.html_url,
        open_issues_count: repo.open_issues_count
      }
    end

    # :reek:UtilityFunction - Data transformation helper
    # :reek:DuplicateMethodCall - issue.user accessed for both login and avatar
    def normalize_issue_data(issue)
      author = issue.user
      pull_request = issue[:pull_request]
      {
        number: issue.number,
        title: issue.title,
        state: issue.state,
        body: issue.body,
        author_login: author&.login,
        author_avatar_url: author&.avatar_url,
        labels: issue.labels.map { |label| { name: label.name, color: label.color } },
        assignees: issue.assignees.map { |assignee| { login: assignee.login, avatar_url: assignee.avatar_url } },
        comments_count: issue.comments,
        created_at: issue.created_at,
        updated_at: issue.updated_at,
        pull_request: pull_request.present?,
        draft: issue[:draft].present?,
        merged_at: pull_request && pull_request[:merged_at]
      }
    end

    # :reek:UtilityFunction - Data transformation helper
    def normalize_pull_request_data(pull)
      head = pull[:head]
      {
        commits_count: pull[:commits],
        changed_files_count: pull[:changed_files],
        additions: pull[:additions],
        deletions: pull[:deletions],
        merged_at: pull[:merged_at],
        draft: pull[:draft].present?,
        head_sha: head && head[:sha]
      }
    end

    # :reek:UtilityFunction - Data transformation helper
    # :reek:TooManyStatements - Sorts out directories, oversized blobs and binaries
    def normalize_file_contents(contents)
      # A directory path answers with an array of entries. Nothing downstream
      # can display that, and it means the caller asked for the wrong thing.
      return { error: ERROR_FILE_NOT_FOUND } if contents.is_a?(Array)

      encoding = contents[:encoding]
      # "none" is how GitHub reports a blob it declined to inline.
      return { error: ERROR_FILE_TOO_LARGE } unless encoding == "base64"

      decoded = Base64.decode64(contents[:content].to_s).force_encoding(Encoding::UTF_8)

      {
        path: contents[:path],
        size: contents[:size],
        # Anything that is not valid UTF-8 is binary as far as a text view is
        # concerned, and must not be pushed into the response as-is.
        binary: !decoded.valid_encoding?,
        content: decoded.valid_encoding? ? decoded : nil
      }
    end

    # :reek:UtilityFunction - Data transformation helper
    # :reek:TooManyStatements - Flattens a nested commit payload
    def normalize_commit_data(commit)
      details = commit[:commit]
      author_details = details[:author]
      github_author = commit[:author]
      message = details[:message].to_s

      {
        sha: commit[:sha],
        # Git commit messages are a subject line, a blank line, then the body.
        # Split rather than truncate so the list can show the subject and let
        # the body expand.
        subject: message.split("\n", 2).first.to_s,
        body: message.split("\n\n", 2).second.to_s.strip,
        # The git author and the GitHub account are different things and either
        # can be missing: unlinked email addresses have no GitHub user, and
        # avatars only exist for the latter.
        author_name: author_details && author_details[:name],
        author_login: github_author && github_author[:login],
        author_avatar_url: github_author && github_author[:avatar_url],
        authored_at: author_details && author_details[:date]
      }
    end

    # :reek:UtilityFunction - Data transformation helper
    def normalize_pull_request_file_data(file)
      {
        filename: file[:filename],
        previous_filename: file[:previous_filename],
        status: file[:status],
        additions: file[:additions],
        deletions: file[:deletions],
        changes: file[:changes],
        patch: file[:patch]
      }
    end

    # :reek:UtilityFunction - Data transformation helper
    # :reek:DuplicateMethodCall - comment.user accessed for both login and avatar
    def normalize_comment_data(comment)
      author = comment.user
      {
        github_id: comment.id,
        author_login: author&.login,
        author_avatar_url: author&.avatar_url,
        body: comment.body,
        created_at: comment.created_at,
        updated_at: comment.updated_at
      }
    end

    # :reek:UtilityFunction - Data transformation helper
    def normalize_assignable_user_data(user)
      {
        login: user[:login],
        avatar_url: user[:avatarUrl]
      }
    end

    # :reek:UtilityFunction - Data transformation helper
    # :reek:TooManyStatements - Processes multiple field types
    # :reek:NilCheck - Explicit nil check for field_name filtering
    def normalize_project_item_data(item)
      fields = {}

      item.dig(:fieldValues, :nodes)&.each do |field_value|
        field_name = field_value.dig(:field, :name)
        # Skip Title field since it's already shown at the top of the page
        next if field_name.nil? || field_name == "Title"

        field_type = field_value[:__typename]
        value = case field_type
        when "ProjectV2ItemFieldSingleSelectValue"
          field_value[:name]
        when "ProjectV2ItemFieldTextValue"
          field_value[:text]
        when "ProjectV2ItemFieldNumberValue"
          field_value[:number]
        when "ProjectV2ItemFieldDateValue"
          # Include date fields even if empty to show structure
          field_value[:date] || ""
        when "ProjectV2ItemFieldIterationValue"
          field_value[:title]
        else
          nil
        end

        # Include date fields even if empty, skip others that are nil
        fields[field_name] = value if value || field_type == "ProjectV2ItemFieldDateValue"
      end

      {
        project_title: item.dig(:project, :title),
        project_number: item.dig(:project, :number),
        project_url: item.dig(:project, :url),
        fields: fields
      }
    end

    # :reek:UtilityFunction - Data transformation helper
    # :reek:TooManyStatements - Processes multiple event types
    # :reek:FeatureEnvy - Accesses item hash extensively
    def normalize_timeline_item_data(item)
      type_name = item[:__typename]

      case type_name
      when "LabeledEvent"
        {
          type: "labeled",
          id: item[:id],
          created_at: Time.parse(item[:createdAt]),
          actor: item.dig(:actor, :login),
          label: {
            name: item.dig(:label, :name),
            color: item.dig(:label, :color)
          }
        }
      when "UnlabeledEvent"
        {
          type: "unlabeled",
          id: item[:id],
          created_at: Time.parse(item[:createdAt]),
          actor: item.dig(:actor, :login),
          label: {
            name: item.dig(:label, :name),
            color: item.dig(:label, :color)
          }
        }
      when "MilestonedEvent"
        {
          type: "milestoned",
          id: item[:id],
          created_at: Time.parse(item[:createdAt]),
          actor: item.dig(:actor, :login),
          milestone_title: item[:milestoneTitle]
        }
      when "DemilestonedEvent"
        {
          type: "demilestoned",
          id: item[:id],
          created_at: Time.parse(item[:createdAt]),
          actor: item.dig(:actor, :login),
          milestone_title: item[:milestoneTitle]
        }
      when "AddedToProjectV2Event"
        {
          type: "added_to_project",
          id: item[:id],
          created_at: Time.parse(item[:createdAt]),
          actor: item.dig(:actor, :login),
          project_title: item.dig(:project, :title),
          project_number: item.dig(:project, :number)
        }
      when "RemovedFromProjectV2Event"
        {
          type: "removed_from_project",
          id: item[:id],
          created_at: Time.parse(item[:createdAt]),
          actor: item.dig(:actor, :login),
          project_title: item.dig(:project, :title)
        }
      when "ProjectV2ItemStatusChangedEvent"
        {
          type: "status_changed",
          id: item[:id],
          created_at: Time.parse(item[:createdAt]),
          actor: item.dig(:actor, :login),
          previous_status: item[:previousStatus],
          status: item[:status],
          was_automated: item[:wasAutomated],
          project_title: item.dig(:project, :title)
        }
      when "IssueComment"
        {
          type: "comment",
          id: item[:id],
          github_id: item[:databaseId],
          created_at: Time.parse(item[:createdAt]),
          actor: item.dig(:author, :login),
          avatar_url: item.dig(:author, :avatarUrl),
          body: item[:body],
          author_association: item[:authorAssociation]
        }
      when "MergedEvent"
        {
          type: "merged",
          id: item[:id],
          created_at: Time.parse(item[:createdAt]),
          actor: item.dig(:actor, :login),
          merge_ref_name: item[:mergeRefName]
        }
      when "ReadyForReviewEvent"
        {
          type: "ready_for_review",
          id: item[:id],
          created_at: Time.parse(item[:createdAt]),
          actor: item.dig(:actor, :login)
        }
      when "ReviewRequestedEvent"
        reviewer = item[:requestedReviewer] || {}
        {
          type: "review_requested",
          id: item[:id],
          created_at: Time.parse(item[:createdAt]),
          actor: item.dig(:actor, :login),
          reviewer: reviewer[:login] || reviewer[:name]
        }
      when "PullRequestReview"
        comments = item.dig(:comments, :nodes) || []
        {
          type: "review",
          id: item[:id],
          created_at: Time.parse(item[:createdAt]),
          actor: item.dig(:author, :login),
          avatar_url: item.dig(:author, :avatarUrl),
          review_state: item[:state],
          body: item[:body],
          comments: comments.map { |comment| normalize_review_comment(comment) },
          comments_total: item.dig(:comments, :totalCount) || comments.size
        }
      else
        nil
      end
    end

    # An inline review comment, anchored to a line of the diff.
    #
    # `line` is null once a comment goes outdated (the line no longer exists in
    # the current diff), so fall back to the line it was originally left on.
    # :reek:UtilityFunction - Pure shape mapping, kept beside its sibling normalizers
    def normalize_review_comment(comment)
      {
        id: comment[:id],
        body: comment[:body],
        path: comment[:path],
        diff_hunk: comment[:diffHunk],
        outdated: comment[:outdated],
        line: comment[:line] || comment[:originalLine],
        created_at: Time.parse(comment[:createdAt]),
        actor: comment.dig(:author, :login),
        avatar_url: comment.dig(:author, :avatarUrl)
      }
    end
  end
end
