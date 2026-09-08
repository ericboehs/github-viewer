# frozen_string_literal: true

# Builds the GitHub-shaped URLs this application serves, from a Repository
# record.
#
#   https://github.com/rails/rails/pull/1   ->  /rails/rails/pull/1
#   https://va.ghe.com/software/eert/pull/1 ->  /va.ghe.com/software/eert/pull/1
#
# The `direct` helpers at the bottom of config/routes.rb delegate here, so
# controllers, views, components and tests all say `repo_pull_path(repo, 1)`
# rather than spelling out two or three path segments at every call site.
#
# :reek:DataClump - The (context, repository, options) trio is the `direct` helper signature
module RepositoryUrls
  # github.com is the implied host and is left out of the path, so a github.com
  # URL is exactly GitHub's own minus the scheme and host. Any other host is
  # named explicitly, which is what tells the router where the repository lives.
  DEFAULT_DOMAIN = "github.com"

  # Names anything below the repository root when we have not yet learned the
  # repository's default branch. GitHub resolves it the same way it resolves a
  # branch name.
  FALLBACK_REF = "HEAD"

  # Stands in for a ref while Rails generates a path; see escaping_ref.
  REF_PLACEHOLDER = "ref-placeholder-2f9d1f"

  CONSTRAINTS = {
    # A host is recognised by having a dot in it, which is what keeps
    # /rails/rails/issues from parsing as host "rails". GitHub owner names
    # cannot contain dots, so this is not ambiguous in practice.
    github_domain: %r{[^/]+\.[^/]+},

    # The remaining segments only have to stop at a slash. In particular they
    # must allow dots, which Rails' default segment pattern does not:
    # repositories are named things like `docs.rs` and refs like `v8.1.0`.
    owner: %r{[^/]+},
    repo: %r{[^/]+},
    ref: %r{[^/]+},
    sha: %r{[^/]+},

    # Kept numeric so that sibling routes such as `issues/refresh` cannot be
    # read as an issue named "refresh".
    number: /\d+/
  }.freeze

  module_function

  # The path segments identifying a repository, with the host omitted for
  # github.com so the optional `(:github_domain)` segment collapses away.
  def segments(repository)
    domain = repository.github_domain

    {
      github_domain: (domain unless domain == DEFAULT_DOMAIN),
      owner: repository.owner,
      repo: repository.name
    }
  end

  # A directory, or the repository root when nothing below it is named.
  #
  # :reek:TooManyStatements - Splits options into segments before delegating
  def tree_path(context, repository, options = {})
    ref, path, query = split(options)
    place = segments(repository)

    # The repository root is its own URL rather than a tree path with nothing
    # in it, which is how GitHub spells it too.
    return context.gh_repo_path(**place, **query) if ref.blank? && path.blank?

    escaping_ref(resolve_ref(repository, ref)) do |segment|
      context.gh_tree_path(**place, ref: segment, path: path, **query)
    end
  end

  # A file. GitHub distinguishes the two only by this word in the URL, and
  # serves both from the same page.
  def blob_path(context, repository, options = {})
    ref, path, query = split(options)

    # With no path there is no file to name, so this is really a tree URL.
    return tree_path(context, repository, options) if path.blank?

    escaping_ref(resolve_ref(repository, ref)) do |segment|
      context.gh_blob_path(**segments(repository), ref: segment, path: path, **query)
    end
  end

  # A ref's history. Unlike a tree URL this one names no path, so the ref is
  # free to contain slashes.
  def commits_path(context, repository, options = {})
    ref, _path, query = split(options)

    context.gh_commits_path(**segments(repository), ref: resolve_ref(repository, ref), **query)
  end

  # Callers pass the ref and path alongside ordinary query parameters, in the
  # way Rails' own path helpers accept them.
  def split(options)
    query = options.symbolize_keys
    path = query.delete(:path).to_s.gsub(%r{\A/+|/+\z}, "").presence

    [ query.delete(:ref).presence, path, query ]
  end

  # A caller with no ref of its own - a breadcrumb, a repository listing -
  # means the default branch.
  def resolve_ref(repository, ref)
    ref.presence || repository.default_branch.presence || FALLBACK_REF
  end

  # Tree and blob URLs put the ref in one path segment and the file path in the
  # next, so a ref that itself contains slashes - `release/2025-01`,
  # `dependabot/bundler/rails-8.1.0` - would leave the router no way to tell
  # where one ends and the other begins. Percent-encoding the slashes keeps the
  # ref to a single segment, and Rails unescapes it on the way back in, so the
  # controller still sees the ref as written.
  #
  # The substitution happens after generation because url_for would escape the
  # percent sign itself, turning %2F into %252F.
  def escaping_ref(ref)
    return yield(ref) unless ref.include?("/")

    yield(REF_PLACEHOLDER).sub(REF_PLACEHOLDER, ref.gsub("/", "%2F"))
  end

  private_class_method :split, :resolve_ref, :escaping_ref
end
