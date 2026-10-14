# frozen_string_literal: true

# Builds the GitHub-shaped URLs for projects, the way RepositoryUrls does for
# repositories.
#
#   https://github.com/orgs/rails/projects/3    ->  /orgs/rails/projects/3
#   https://va.ghe.com/users/ericboehs/projects/1 ->  /va.ghe.com/users/ericboehs/projects/1
#
# Projects hang off an organization or a user rather than a repository, so
# their paths start with GitHub's `orgs` or `users` segment instead of an owner
# and a repository name. That is also why these routes have to be declared
# before the repository scope in config/routes.rb: `/orgs/rails/projects` is
# three segments and would otherwise read as the repository `orgs/rails`.
#
# :reek:DataClump - The (context, project, options) trio is the `direct` helper signature
module ProjectUrls
  DEFAULT_DOMAIN = RepositoryUrls::DEFAULT_DOMAIN

  ORGANIZATION = "orgs"
  USER = "users"

  # GraphQL answers with the type of the owner; these are GitHub's paths for
  # the same two things.
  OWNER_TYPES = { "Organization" => ORGANIZATION, "User" => USER }.freeze

  CONSTRAINTS = {
    github_domain: RepositoryUrls::CONSTRAINTS[:github_domain],
    owner_type: /#{ORGANIZATION}|#{USER}/,
    login: %r{[^/]+},
    number: /\d+/,
    view_number: /\d+/
  }.freeze

  module_function

  def owner_type_for(typename)
    OWNER_TYPES.fetch(typename.to_s, ORGANIZATION)
  end

  # True for the path segment, so a controller can tell which GraphQL root to
  # ask - `organization(login:)` or `user(login:)`.
  def organization?(owner_type)
    owner_type.to_s != USER
  end

  # github.com is the implied host here too, so naming it is left out of the
  # path and the optional segment collapses away.
  def segments(domain, owner_type, login)
    {
      github_domain: (domain unless domain == DEFAULT_DOMAIN),
      owner_type: owner_type,
      login: login
    }
  end

  def project_segments(project)
    segments(project.github_domain, project.owner_type, project.owner_login).merge(number: project.number)
  end

  # A project, or one of its saved views when `view:` names one. GitHub spells
  # a view as a trailing `/views/2`, and its first view as the project itself.
  def path(context, project, options = {})
    query = options.symbolize_keys
    view_number = query.delete(:view).presence
    place = project_segments(project)

    return context.gh_project_view_path(**place, view_number: view_number, **query) if view_number

    context.gh_project_path(**place, **query)
  end

  # Ours rather than GitHub's: the endpoint each lazily loaded page of items
  # comes from. See ProjectsController#items.
  def items_path(context, project, options = {})
    context.gh_project_items_path(**project_segments(project), **options.symbolize_keys)
  end

  # Every project of one owner.
  def list_path(context, owner, options = {})
    context.gh_projects_path(**segments(owner.github_domain, owner.owner_type, owner.login), **options.symbolize_keys)
  end
end
