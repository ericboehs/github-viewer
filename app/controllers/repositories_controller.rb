# frozen_string_literal: true

# Controller for managing tracked GitHub repositories
class RepositoriesController < ApplicationController
  include RepositoriesHelper

  def index
    @repositories = Current.user.repositories.order(cached_at: :desc)
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

  private

  def repository_params
    params.require(:repository).permit(:url)
  end
end
