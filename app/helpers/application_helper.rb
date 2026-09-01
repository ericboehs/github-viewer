# Base module for application-wide view helpers
module ApplicationHelper
  include Pagy::Frontend

  # Renders a <time> tag with automatic relative time display and full datetime tooltip
  #
  # @param datetime [Time, DateTime, ActiveSupport::TimeWithZone] The datetime to display
  # @param options [Hash] Additional HTML options for the time tag
  # @return [String] HTML time tag with Stimulus controller
  #
  # @example
  #   <%= time_ago_tag(@issue.github_created_at) %>
  #   # => <time datetime="2025-10-30T12:34:56Z" data-controller="time">2 hours ago</time>
  def time_ago_tag(datetime, **options)
    return "" if datetime.blank?

    data_options = options[:data] || {}
    data_options[:controller] = "time"
    options[:data] = data_options

    content_tag :time, time_ago_in_words(datetime) + " ago", datetime: datetime.utc.iso8601, **options
  end

  # Canonical GitHub URL for an issue or pull request
  #
  # @param repository [Repository]
  # @param issue [Issue]
  # @return [String] e.g. https://github.com/rails/rails/pull/123
  # :reek:FeatureEnvy - Builds a URL from repository and issue attributes
  def github_item_url(repository = @repository, issue = @issue)
    kind = issue.pull_request? ? "pull" : "issues"
    "https://#{repository.github_domain}/#{repository.owner}/#{repository.name}/#{kind}/#{issue.number}"
  end
end
