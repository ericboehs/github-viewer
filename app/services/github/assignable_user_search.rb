module Github
  # Finds the users who can be assigned to an issue, for the filter dropdowns.
  #
  # Backed by the locally synced repository_assignable_users table. The list
  # used to come straight from `repository_assignees` with auto_paginate on,
  # which walked every page of an organisation's membership on every keystroke
  # — around a minute per request against a large enterprise org, holding a
  # Puma thread the whole time.
  #
  # For an ordinary repository the synced list is everyone, and the answer
  # comes out of SQLite in a millisecond or two. For an org too large to sync
  # in full, a search that comes up short is topped up with GitHub's own
  # server-side matching, so a name the sync never reached is still findable.
  # :reek:TooManyMethods - Small private steps read better than one long method
  # :reek:TooManyInstanceVariables - Inputs plus memoized token/viewer/client
  # :reek:InstanceVariableAssumption - @token and @viewer memoize a nullable lookup
  class AssignableUserSearch
    LIMIT = 20

    def initialize(repository:, user:, query: nil, selected: nil)
      @repository = repository
      @user = user
      @query = query
      @selected = selected
    end

    def call
      schedule_sync

      pinned + matches.reject { |entry| pinned_logins.include?(entry[:login]) }
    end

    private

    attr_reader :repository, :user, :query, :selected

    # Keep the cache warm without ever blocking on it. Search covers whatever
    # the sync has not reached yet, so there is no reason to make anyone wait.
    # :reek:DuplicateMethodCall - repository.id used for the job and the log line
    def schedule_sync
      return unless synced_users.empty? || stale?

      SyncRepositoryAssignableUsersJob.perform_later(repository.id)
    rescue StandardError => error
      # A failed enqueue must not take out the dropdown.
      Rails.logger.error "Failed to sync assignable users for repository #{repository.id}: #{error.message}"
    end

    # :reek:FeatureEnvy - Compares the timestamp against the TTL
    def stale?
      last_synced = synced_users.maximum(:updated_at)

      last_synced.blank? || last_synced < ApiConfiguration::ASSIGNABLE_USERS_TTL.ago
    end

    def matches
      local = local_matches
      return local if query.blank? || local.length >= LIMIT || complete?

      merge_remote(local)
    end

    def local_matches
      synced_users.search(query).ordered.limit(LIMIT).map do |record|
        { login: record.login, avatar_url: record.avatar_url }
      end
    end

    # Whether the synced list is everyone, rather than as far as the page cap
    # got. An ordinary repository never needs the extra round-trip.
    def complete?
      synced_users.count < ApiConfiguration::MAX_ASSIGNABLE_USER_PAGES * 100
    end

    # :reek:FeatureEnvy - Merging two lists of entry hashes is the whole job
    # :reek:DuplicateMethodCall - Reads :login from different entries
    def merge_remote(local)
      seen = local.map { |entry| entry[:login] }
      extra = remote_matches.reject { |entry| seen.include?(entry[:login]) }

      (local + extra).first(LIMIT)
    end

    def remote_matches
      return [] unless token

      client.search_assignable_users(repository.owner, repository.name, query, limit: LIMIT)
    rescue StandardError => error
      Rails.logger.warn "Assignable user search failed for #{repository.full_name}: #{error.message}"
      []
    end

    # The selected user, then the viewer, so the active filter and "me" stay
    # visible even when they fall outside the matches.
    def pinned
      entries = []
      entries << entry_for(selected) if selected.present?
      entries << entry_for(viewer_login, fallback_avatar: viewer&.dig(:avatar_url)) if pin_viewer?

      entries
    end

    def pin_viewer?
      viewer_login.present? &&
        viewer_login != selected &&
        viewer_login.downcase.include?(query.to_s.downcase)
    end

    def pinned_logins
      @pinned_logins ||= pinned.map { |entry| entry[:login] }
    end

    def entry_for(login, fallback_avatar: nil)
      record = synced_users.find_by(login: login)

      { login: login, avatar_url: record&.avatar_url || fallback_avatar }
    end

    def viewer_login
      viewer && viewer[:login]
    end

    # The viewer's own login and avatar, so they can be pinned even when the
    # sync never reached their name. Cached because it never changes for a
    # given token and the dropdown asks on every keystroke.
    def viewer
      return @viewer if defined?(@viewer)

      @viewer = token && fetch_viewer
    end

    # :reek:TooManyStatements - Cache fetch plus error handling
    def fetch_viewer
      Rails.cache.fetch([ "github_viewer", token.id ], expires_in: ApiConfiguration::ASSIGNABLE_USERS_TTL) do
        account = client.client.user
        { login: account.login, avatar_url: account.avatar_url }
      end
    rescue StandardError => error
      Rails.logger.warn "Could not determine GitHub login for #{domain}: #{error.message}"
      nil
    end

    def synced_users
      repository.repository_assignable_users
    end

    def token
      return @token if defined?(@token)

      @token = user.github_token_for(domain)
    end

    def client
      @client ||= ApiClient.new(token: token.token, domain: domain)
    end

    def domain
      repository.github_domain
    end
  end
end
