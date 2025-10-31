# frozen_string_literal: true

# Helper methods for repository management
module RepositoriesHelper
  # Parses a GitHub repository URL or shorthand and extracts components
  #
  # Supports formats:
  #   - https://github.com/owner/repo
  #   - https://github.example.com/owner/repo
  #   - github.com/owner/repo
  #   - owner/repo (defaults to github.com)
  #   - URLs with .git suffix, trailing slashes, etc.
  #
  # Returns hash with :domain, :owner, :name keys or nil if invalid
  # :reek:TooManyStatements - URL parsing requires multiple sanitization and format checks
  # :reek:FeatureEnvy - String manipulation methods are appropriate for parsing logic
  def parse_repository_url(url_or_shorthand)
    return nil if url_or_shorthand.blank?

    input = url_or_shorthand.strip

    # Remove .git suffix if present
    input = input.sub(/\.git$/, "")

    # Remove trailing slashes
    input = input.sub(%r{/+$}, "")

    # Try to parse as URL first
    if input.match?(%r{^https?://})
      parse_full_url(input)
    elsif input.include?("/")
      parse_shorthand(input)
    else
      nil # Invalid format
    end
  end

  private

  # Parse full URL format: https://github.com/owner/repo
  # :reek:TooManyStatements - URL parsing requires validation and extraction steps
  # :reek:UtilityFunction - Helper method for URL parsing, appropriately placed
  # :reek:DuplicateMethodCall - uri.host accessed for validation and result hash
  def parse_full_url(url)
    uri = URI.parse(url)
    return nil unless uri.host

    path_parts = uri.path.split("/").reject(&:blank?)
    return nil unless path_parts.length >= 2

    {
      domain: uri.host,
      owner: path_parts[0],
      name: path_parts[1]
    }
  rescue URI::InvalidURIError
    nil
  end

  # Parse shorthand format: github.com/owner/repo or owner/repo
  # :reek:UtilityFunction - Helper method for shorthand parsing, appropriately placed
  # :reek:DuplicateMethodCall - parts array accessed multiple times for clarity
  def parse_shorthand(input)
    parts = input.split("/").reject(&:blank?)

    if parts.length == 2
      # owner/repo format - default to github.com
      {
        domain: "github.com",
        owner: parts[0],
        name: parts[1]
      }
    elsif parts.length == 3
      # domain/owner/repo format
      {
        domain: parts[0],
        owner: parts[1],
        name: parts[2]
      }
    else
      nil
    end
  end
end
