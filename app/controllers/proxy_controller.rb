# frozen_string_literal: true

# Provides on-demand issue viewing via proxy-style URLs
# e.g., /va.ghe.com/software/eert/issues/185
# e.g., /rails/rails/issues/123 (defaults to github.com)
# e.g., /rails/rails/pull/123 (pull requests)
# :reek:TooManyStatements - Controller orchestrates path parsing, repo sync, and issue fetch
# :reek:InstanceVariableAssumption - Controller sets instance variables for views
# :reek:TooManyInstanceVariables - Proxy needs domain, owner, repo_name, issue_number, repository
class ProxyController < ApplicationController
  include IssueShowable

  def show
    parsed = parse_proxy_path(params[:path])
    unless parsed
      redirect_to root_path, alert: "Invalid issue URL format. Expected: domain/owner/repo/issues/123 or owner/repo/issues/123"
      return
    end

    @domain = parsed[:domain]
    @owner = parsed[:owner]
    @repo_name = parsed[:name]
    @issue_number = parsed[:issue_number]
    @list_scope = parsed[:scope]

    # Check user has a token for this domain
    current_user = Current.user
    unless current_user.github_tokens.exists?(domain: @domain)
      redirect_to root_path, alert: "No GitHub token configured for #{@domain}. Add one in your settings."
      return
    end

    # Find or create the repository
    @repository = find_or_create_repository(current_user)
    return unless @repository

    # Fetch and display the issue using shared concern
    load_and_display_issue
  end

  private

  # Proxy URLs mirror GitHub's own paths, so /pull/123 renders in the pulls scope
  def list_scope
    @list_scope || IssueScoped::ISSUES_SCOPE
  end

  def issue_not_found_redirect_path
    root_path
  end

  # :reek:UtilityFunction - Pure path parsing function
  # :reek:DuplicateMethodCall - Accessing repo_segments indices for readability
  # :reek:TooManyStatements - Parses domain, owner, repo, kind, and number
  def parse_proxy_path(path)
    return nil if path.blank?

    segments = path.split("/")

    # Need at least owner/repo/issues/number (4 segments)
    return nil unless segments.length >= 4
    kind = segments[-2]
    return nil unless kind.in?(%w[issues pull])

    issue_number = segments[-1].to_i
    return nil if issue_number <= 0

    scope = kind == "pull" ? IssueScoped::PULLS_SCOPE : IssueScoped::ISSUES_SCOPE

    # Remove /issues/number from segments
    repo_segments = segments[0..-3]
    first_segment = repo_segments[0]

    case repo_segments.length
    when 2
      # owner/repo -> default github.com
      { domain: "github.com", owner: first_segment, name: repo_segments[1], issue_number: issue_number, scope: scope }
    when 3
      if first_segment.include?(".")
        # domain/owner/repo
        { domain: first_segment, owner: repo_segments[1], name: repo_segments[2], issue_number: issue_number, scope: scope }
      end
    end
  end

  # :reek:TooManyStatements - Orchestrates lookup and sync fallback
  def find_or_create_repository(current_user)
    repo = current_user.repositories.find_by(
      github_domain: @domain,
      owner: @owner,
      name: @repo_name
    )
    return repo if repo

    # Auto-create by syncing from GitHub
    result = Github::RepositorySyncService.new(
      user: current_user,
      github_domain: @domain,
      owner: @owner,
      repo_name: @repo_name
    ).call

    if result[:success]
      result[:repository]
    else
      redirect_to root_path, alert: "Could not find repository #{@owner}/#{@repo_name} on #{@domain}: #{result[:error]}"
      nil
    end
  end
end
