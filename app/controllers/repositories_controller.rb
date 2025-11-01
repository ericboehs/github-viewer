# frozen_string_literal: true

# Controller for managing tracked GitHub repositories
# :reek:InstanceVariableAssumption - Controller sets instance variables for views
class RepositoriesController < ApplicationController
  include RepositoriesHelper

  def index
    @repositories = Current.user.repositories.order(cached_at: :desc)
    redirect_to new_repository_path if @repositories.empty?
  end

  def new
    @repository = Repository.new
  end

  # :reek:TooManyStatements - Controller action orchestrates URL parsing, duplicate check, and API sync
  # :reek:NilCheck - Explicit nil check required for URL parsing validation
  # :reek:DuplicateMethodCall - Parsed hash and Current.user accessed multiple times for readability
  def create
    parsed = parse_repository_url(repository_params[:url])

    if parsed.nil?
      redirect_to repositories_path, alert: t("repositories.errors.invalid_url")
      return
    end

    # Check if repository already exists
    existing = Current.user.repositories.find_by(
      github_domain: parsed[:domain],
      owner: parsed[:owner],
      name: parsed[:name]
    )

    if existing
      redirect_to repositories_path, alert: t("repositories.errors.already_tracked")
      return
    end

    # Sync repository from GitHub
    result = Github::RepositorySyncService.new(
      user: Current.user,
      github_domain: parsed[:domain],
      owner: parsed[:owner],
      repo_name: parsed[:name]
    ).call

    if result[:success]
      redirect_to repositories_path, notice: t("repositories.create.success")
    else
      redirect_to repositories_path, alert: t("repositories.create.error", error: result[:error])
    end
  end

  def destroy
    repository = Current.user.repositories.find(params[:id])
    repository.destroy

    redirect_to repositories_path, notice: t("repositories.destroy.success")
  end

  # :reek:DuplicateMethodCall - Current.user accessed for repository lookup and service
  def refresh
    repository = Current.user.repositories.find(params[:id])

    result = Github::RepositorySyncService.new(
      user: Current.user,
      github_domain: repository.github_domain,
      owner: repository.owner,
      repo_name: repository.name
    ).call

    if result[:success]
      redirect_to repositories_path, notice: t("repositories.refresh.success")
    else
      redirect_to repositories_path, alert: t("repositories.refresh.error", error: result[:error])
    end
  end

  # Search assignable users for filter dropdowns (JSON endpoint)
  # Returns assignable users matching the query
  # Used for both Author and Assignee dropdowns
  # :reek:TooManyStatements - JSON endpoint needs query building, filtering, and response
  # :reek:DuplicateMethodCall - Repeated calls are part of query chain logic
  # :reek:FeatureEnvy - Manipulating users collection is the purpose of this endpoint
  def assignable_users
    repository = Current.user.repositories.find(params[:id])
    query = params[:q]
    selected = params[:selected]

    # Query assignable users from database
    users = repository.repository_assignable_users.ordered

    # Filter by search query if provided
    users = users.search(query) if query.present?

    # Limit to 20 results for dropdown
    users = users.limit(20).to_a

    # If a selected user is specified and not in results, add them at the beginning
    if selected.present?
      selected_user = repository.repository_assignable_users.find_by(login: selected)
      if selected_user && !users.any? { |user| user.login == selected }
        users.unshift(selected_user)
        users = users.first(20) # Keep limit at 20
      end
    end

    # Return JSON
    render json: users.map { |user|
      {
        login: user.login,
        avatar_url: user.avatar_url
      }
    }
  end

  private

  def repository_params
    params.require(:repository).permit(:url)
  end
end
