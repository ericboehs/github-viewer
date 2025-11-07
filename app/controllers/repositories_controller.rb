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
  # Fetches repository assignees from GitHub REST API
  # Used for both Author and Assignee dropdowns
  # :reek:TooManyStatements - JSON endpoint needs API call, filtering, and response
  # :reek:DuplicateMethodCall - Repeated calls are part of filtering logic
  def assignable_users
    repository = Current.user.repositories.find(params[:id])
    query = params[:q]
    selected = params[:selected]

    # Fetch collaborators from GitHub REST API
    github_token = Current.user.github_tokens.find_by(domain: repository.github_domain)
    unless github_token
      render json: { error: "No GitHub token found for #{repository.github_domain}" }, status: :unauthorized
      return
    end

    begin
      client = Github::ApiClient.new(token: github_token.token, domain: repository.github_domain)

      # Fetch current authenticated user
      current_github_user = client.client.user
      current_user_login = current_github_user.login

      # Fetch assignable users from GitHub REST API
      assignees = client.client.repository_assignees(repository.full_name, per_page: 100)

      # Convert to hash format expected by frontend
      users = assignees.map do |user|
        {
          login: user.login,
          avatar_url: user.avatar_url  # Keep token - it's required for GHE and fresh from API
        }
      end

      # If there's a selected user, try to find or fetch them
      selected_user_data = nil
      if selected.present?
        selected_user_data = users.find { |user| user[:login] == selected }
        unless selected_user_data
          # Selected user not in first 100 results - try to fetch them directly from GitHub
          begin
            user_info = client.client.user(selected)
            selected_user_data = {
              login: user_info.login,
              avatar_url: user_info.avatar_url
            }
          rescue Octokit::NotFound
            # User doesn't exist or isn't accessible - skip adding them
            Rails.logger.warn "Selected user #{selected} not found on GitHub"
          end
        end
      end

      # Filter by search query if provided
      if query.present?
        lowerQuery = query.downcase
        users = users.select { |user| user[:login].downcase.include?(lowerQuery) }
      end

      # Find current user in the list
      current_user_data = users.find { |user| user[:login] == current_user_login }

      # Only add current user if they match the search query (or no query)
      unless current_user_data
        # Check if current user matches the query (if there is one)
        if query.blank? || current_user_login.downcase.include?(query.downcase)
          # Current user not in results but matches query - add them
          current_user_data = {
            login: current_github_user.login,
            avatar_url: current_github_user.avatar_url
          }
        end
      end

      # Remove selected and current users from the list
      users.reject! { |user| user[:login] == selected || user[:login] == current_user_login }

      # Add users in priority order: selected first (if present), then current user (if matches query), then everyone else
      prioritized_users = []
      prioritized_users << selected_user_data if selected_user_data
      prioritized_users << current_user_data if current_user_data && current_user_data[:login] != selected
      users = prioritized_users + users

      # Limit to 20 results for dropdown
      users = users.first(20)

      render json: users
    rescue => e
      Rails.logger.error "Error fetching assignable users: #{e.message}"
      render json: { error: "Failed to fetch assignable users" }, status: :internal_server_error
    end
  end

  private

  def repository_params
    params.require(:repository).permit(:url)
  end
end
