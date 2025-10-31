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
  end
end
