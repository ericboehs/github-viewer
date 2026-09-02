# frozen_string_literal: true

module Github
  # Centralized configuration for GitHub API client behavior
  # :reek:TooManyConstants - Configuration class by nature contains many constants
  class ApiConfiguration
    # Rate limiting thresholds
    CRITICAL_RATE_LIMIT_THRESHOLD = 50
    WARNING_RATE_LIMIT_THRESHOLD = 200

    # Search API specific thresholds (search has 30/min limit)
    SEARCH_CRITICAL_THRESHOLD = 3
    SEARCH_WARNING_THRESHOLD = 10

    # Retry configuration
    MAX_RETRIES = 3
    RETRY_BACKOFF_BASE = 2

    # Sleep delays (in seconds)
    DEFAULT_RATE_LIMIT_DELAY = 0.1
    MAX_RETRY_DELAY = 60
    MIN_CRITICAL_DELAY = 1.0

    # Pagination
    DEFAULT_PAGE_SIZE = 100

    # GraphQL query limits
    GRAPHQL_PAGE_SIZE = 100

    # HTTP timeouts (in seconds).
    #
    # Without these, a GitHub Enterprise host that accepts a connection but
    # never answers pins the request until Net::HTTP's 60s default. In
    # development that is a whole Puma thread, so a single hung dropdown fetch
    # stalls every other request behind it.
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 15

    # Assignable users
    #
    # The synced list is a warm cache for the dropdown, not the source of
    # truth: a search that comes up short falls back to GitHub's own
    # server-side matching. Cap what one sync will walk so a huge enterprise
    # org cannot turn a background refresh into an all-day job. This runs in
    # the background, so it can afford to be generous.
    MAX_ASSIGNABLE_USER_PAGES = 30

    # How long a cached assignable-user list stays authoritative before the
    # next request refreshes it in the background.
    ASSIGNABLE_USERS_TTL = 12.hours
  end
end
