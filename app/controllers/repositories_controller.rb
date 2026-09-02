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

  # Assignable users for the Author and Assignee filter dropdowns (JSON).
  def assignable_users
    user = Current.user

    render json: Github::AssignableUserSearch.new(
      repository: user.repositories.find(params[:id]),
      user: user,
      query: params[:q],
      selected: params[:selected]
    ).call
  end

  # :reek:TooManyStatements - Controller action orchestrates API call and data transformation
  def labels
    user = Current.user
    repository = user.repositories.find(params[:id])
    domain = repository.github_domain
    query = params[:q]

    # Fetch labels from GitHub API
    github_token = user.github_token_for(domain)
    unless github_token
      render json: { error: "No GitHub token found for #{domain}" }, status: :unauthorized
      return
    end

    begin
      client = Github::ApiClient.new(token: github_token.token, domain: domain)
      labels = client.fetch_labels(repository.owner, repository.name)

      # Convert to array of hashes with name and color
      labels_data = labels.map do |label|
        {
          name: label.name,
          color: label.color
        }
      end

      # Filter by search query if provided
      if query.present?
        lower_query = query.downcase
        labels_data = labels_data.select { |label| label[:name].downcase.include?(lower_query) }
      end

      # Limit to 50 results for dropdown
      labels_data = labels_data.first(50)

      render json: labels_data
    rescue => error
      Rails.logger.error "Error fetching labels: #{error.message}"
      render json: { error: "Failed to fetch labels" }, status: :internal_server_error
    end
  end

  private

  def repository_params
    params.require(:repository).permit(:url)
  end
end
