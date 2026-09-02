# frozen_string_literal: true

# Provides on-demand viewing via proxy-style URLs that mirror GitHub's own
# e.g., /va.ghe.com/software/eert/issues/185
# e.g., /rails/rails/issues/123 (defaults to github.com)
# e.g., /rails/rails/pull/123 (pull requests)
# e.g., /va.ghe.com/software/eert/blob/main/README.md (files and directories)
# :reek:TooManyStatements - Controller orchestrates path parsing, repo sync, and issue fetch
# :reek:InstanceVariableAssumption - Controller sets instance variables for views
# :reek:TooManyInstanceVariables - Proxy needs domain, owner, repo_name, issue_number, repository
class ProxyController < ApplicationController
  include IssueShowable

  def show
    parsed = ProxyPath.parse(params[:path])
    unless parsed
      redirect_to root_path, alert: "Invalid GitHub URL format. Expected: domain/owner/repo/issues/123 or domain/owner/repo/blob/ref/path"
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

    # A blob or tree URL has no issue to load; it is just a way of naming a
    # path, so hand off to the file browser.
    return redirect_to repository_tree_path(@repository, path: parsed[:path], ref: parsed[:ref]) if parsed[:kind] == :tree

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
