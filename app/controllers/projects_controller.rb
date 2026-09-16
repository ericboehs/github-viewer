# frozen_string_literal: true

# Reading GitHub Projects V2: an owner's projects, a repository's linked
# projects, and one project's board or table.
#
# Projects are read live rather than cached, the way branches and commits are.
# There is no REST endpoint for them at all, so everything here goes through
# GraphQL, and `ProjectV2.items` takes no filter argument: a filtered board is
# the whole project fetched and then narrowed in Ruby. That is why items arrive
# a page at a time - the first with the page, the rest through the chained
# frames `#items` answers - rather than the request holding open until the last
# cursor comes back.
#
# :reek:InstanceVariableAssumption - Controller sets instance variables for views
# :reek:TooManyInstanceVariables - A project page is an owner, a project, a view, a layout, a filter and a page of items
class ProjectsController < ApplicationController
  include RepositoryScoped
  include LiveGithubData

  # A project's fields and saved views are re-read for every page of its items,
  # and change far less often than the items do. Caching the shape of a project
  # for a few minutes keeps each of those requests to one API call; the items
  # themselves are never cached.
  PROJECT_TTL = 5.minutes

  before_action :set_repository, only: :linked
  before_action :set_owner, except: :linked
  before_action :set_project, only: [ :show, :items ]
  before_action :set_view, only: [ :show, :items ]

  helper_method :view_param

  # GitHub's repository Projects tab: a repository does not own projects, it
  # links to them, and every one of them may belong to another owner entirely.
  def linked
    @projects = fetch_live(fallback: []) do |client, owner, name|
      client.fetch_repository_projects(owner, name)
    end
  end

  def index
    @projects = fetch_from_github(fallback: []) do |client|
      client.fetch_owner_projects(@owner.login, organization: @owner.organization?)
    end
  end

  def show
    @chunk = load_chunk
    report_unknown_qualifiers
  end

  # One later page of items, for the frame the previous page left behind.
  def items
    @chunk = load_chunk(page: [ params[:page].to_i, 2 ].max, after: params[:after], offset: params[:offset].to_i)

    render layout: false
  end

  private

  # The view as a parameter, which is absent when it is the project's first:
  # that one is the project's own path, the way GitHub spells it.
  def view_param
    view = @view
    view.number if view && view != @project.default_view
  end

  def live_domain
    @repository&.github_domain || @owner.github_domain
  end

  def set_owner
    return redirect_to canonical_path, status: :moved_permanently if redundant_domain?

    @owner = Projects::Owner.new(
      github_domain: github_domain_param,
      owner_type: params[:owner_type].presence || ProjectUrls::ORGANIZATION,
      login: params[:login].to_s
    )
  end

  # Halts the callback chain when the project cannot be read, so the actions
  # can assume it is there.
  def set_project
    @project = cached_project
    return if @project

    # A frame asking for more items has nowhere useful to send the reader, and
    # the page it belongs to has already reported the failure.
    return head(:no_content) if action_name == "items"

    redirect_to owner_projects_path(@owner), alert: flash[:alert]
  end

  def cached_project
    Rails.cache.fetch(project_cache_key, expires_in: PROJECT_TTL, skip_nil: true) do
      fetch_from_github do |client|
        client.fetch_project(@owner.login, params[:number], organization: @owner.organization?)
      end
    end
  end

  # Per user, because which projects a token can see is a property of the
  # token.
  def project_cache_key
    [ "projects", Current.user.id, @owner.github_domain, @owner.owner_type, @owner.login, params[:number] ]
  end

  def set_view
    @view = @project.view(params[:view_number]) || @project.default_view
    @layout = Projects::Layout.for(project: @project, view: @view)
    @filter = Projects::Filter.new(filter_query, project: @project)
  end

  # An unedited filter box holds the view's own filter; `q` is what the reader
  # typed instead, and an empty `q` is a deliberately cleared box rather than
  # an absent one.
  def filter_query
    params.has_key?(:q) ? params[:q] : @view&.filter
  end

  def load_chunk(page: 1, after: nil, offset: 0)
    result = fetch_from_github(fallback: Projects::Page::EMPTY) do |client|
      client.fetch_project_items(@project.id, after: after, offset: offset)
    end

    Projects::Chunk.build(result: result, filter: @filter, page: page, offset: offset)
  end

  # A qualifier naming neither a built-in nor one of this project's fields
  # matches nothing, which looks exactly like an empty project unless the page
  # says otherwise.
  def report_unknown_qualifiers
    unknown = @filter.unknown_keys
    return if unknown.empty?

    flash.now[:notice] = t("projects.show.unknown_qualifiers", qualifiers: unknown.join(", "))
  end
end
