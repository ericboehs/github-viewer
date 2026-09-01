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
    # The dropdown shows 20 rows and searches server-side, so paging through an
    # entire enterprise org (tens of thousands of members) to build the list is
    # pure waste. Cap what we will walk in one sync.
    MAX_ASSIGNABLE_USER_PAGES = 5

    # How long a cached assignable-user list stays authoritative before the
    # next request refreshes it in the background.
    ASSIGNABLE_USERS_TTL = 12.hours
  end
end
