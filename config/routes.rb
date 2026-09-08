Rails.application.routes.draw do
  resource :user, only: [ :show, :edit, :update ]
  get "dashboard/index"
  resource :session
  resources :passwords, param: :token
  resources :users, only: [ :new, :create ]
  resources :github_tokens, only: [ :create, :destroy ]

  # Managing the list of tracked repositories. Viewing one happens under its
  # GitHub-shaped URL instead - see below.
  resources :repositories, only: [ :index, :new, :create, :destroy ]

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "dashboard#index"

  # --------------------------------------------------------------------------
  # GitHub-shaped repository URLs
  #
  # Every page about a repository lives at the same path GitHub itself uses, so
  # a link can be pasted here with only the scheme and host removed:
  #
  #   https://github.com/rails/rails/pull/1    -> /rails/rails/pull/1
  #   https://va.ghe.com/software/eert/pull/1  -> /va.ghe.com/software/eert/pull/1
  #
  # The host segment is optional and defaults to github.com, which is why it
  # has to look like a hostname; see RepositoryUrls::CONSTRAINTS.
  #
  # A new repository page - branches, discussions, actions - is one more line
  # in this scope plus a matching `direct` below, and inherits the host
  # handling and the repository lookup in RepositoryScoped for free.
  #
  # `format: false` because these paths end in file extensions that Rails would
  # otherwise strip as a response format, turning README.md into README. The
  # html default goes with it: with no `.:format` segment left to read, Rails
  # falls back to guessing the format from the path's extension, and would
  # answer a request for a Markdown file with "406 Not Acceptable".
  #
  # They are declared last so an application route always wins over a
  # repository that happens to be named after one (/repositories, /session...).
  # --------------------------------------------------------------------------
  scope "(:github_domain)/:owner/:repo", constraints: RepositoryUrls::CONSTRAINTS,
        format: false, defaults: { format: "html" } do
    # Refreshing is ours rather than GitHub's, so it sits on paths GitHub
    # leaves free.
    post "refresh", to: "repositories#refresh", as: :gh_refresh
    # The filter dropdowns' data sources, and the only routes here that answer
    # with something other than a page.
    get "assignable_users", to: "repositories#assignable_users", as: :gh_assignable_users, defaults: { format: "json" }
    get "labels", to: "repositories#labels", as: :gh_labels, defaults: { format: "json" }

    get "issues", to: "issues#index", as: :gh_issues
    post "issues/refresh", to: "issues#refresh", as: :gh_issues_refresh
    get "issues/:number", to: "issues#show", as: :gh_issue
    post "issues/:number/refresh", to: "issues#refresh", as: :gh_issue_refresh

    # GitHub spells the list "pulls" and a single pull request "pull".
    get "pulls", to: "pulls#index", as: :gh_pulls
    post "pulls/refresh", to: "pulls#refresh", as: :gh_pulls_refresh
    get "pull/:number", to: "pulls#show", as: :gh_pull
    post "pull/:number/refresh", to: "pulls#refresh", as: :gh_pull_refresh
    get "pull/:number/commits", to: "pulls#commits", as: :gh_pull_commits
    get "pull/:number/files", to: "pulls#files", as: :gh_pull_files
    get "pull/:number/files/*path", to: "pulls#file", as: :gh_pull_file

    # One action serves both: a `tree` URL that turns out to name a file still
    # renders the file, as GitHub's does.
    get "tree/:ref(/*path)", to: "trees#show", as: :gh_tree
    get "blob/:ref/*path", to: "trees#show", as: :gh_blob
  end

  # The repository root, which GitHub renders as its default branch's tree.
  get "(:github_domain)/:owner/:repo", to: "trees#show", as: :gh_repo,
      constraints: RepositoryUrls::CONSTRAINTS, format: false, defaults: { format: "html" }

  # --------------------------------------------------------------------------
  # Object-friendly wrappers for the routes above.
  #
  # `repo_pull_path(repository, 1)` rather than repeating the two or three path
  # segments at every call site. Being `direct` routes rather than a helper
  # module, they are available anywhere the generated route helpers are:
  # controllers, views, components, mailers and tests.
  #
  # Each block receives the arguments given to the helper plus an options hash,
  # which carries query parameters such as `q:` through to the underlying
  # route.
  # --------------------------------------------------------------------------
  direct(:repo) { |repository, options| gh_repo_path(**RepositoryUrls.segments(repository), **options) }
  direct(:refresh_repo) { |repository, options| gh_refresh_path(**RepositoryUrls.segments(repository), **options) }
  direct(:repo_assignable_users) { |repository, options| gh_assignable_users_path(**RepositoryUrls.segments(repository), **options) }
  direct(:repo_labels) { |repository, options| gh_labels_path(**RepositoryUrls.segments(repository), **options) }

  direct(:repo_issues) { |repository, options| gh_issues_path(**RepositoryUrls.segments(repository), **options) }
  direct(:refresh_repo_issues) { |repository, options| gh_issues_refresh_path(**RepositoryUrls.segments(repository), **options) }
  direct(:repo_issue) { |repository, number, options| gh_issue_path(**RepositoryUrls.segments(repository), number: number, **options) }
  direct(:refresh_repo_issue) { |repository, number, options| gh_issue_refresh_path(**RepositoryUrls.segments(repository), number: number, **options) }

  direct(:repo_pulls) { |repository, options| gh_pulls_path(**RepositoryUrls.segments(repository), **options) }
  direct(:refresh_repo_pulls) { |repository, options| gh_pulls_refresh_path(**RepositoryUrls.segments(repository), **options) }
  direct(:repo_pull) { |repository, number, options| gh_pull_path(**RepositoryUrls.segments(repository), number: number, **options) }
  direct(:refresh_repo_pull) { |repository, number, options| gh_pull_refresh_path(**RepositoryUrls.segments(repository), number: number, **options) }
  direct(:repo_pull_commits) { |repository, number, options| gh_pull_commits_path(**RepositoryUrls.segments(repository), number: number, **options) }
  direct(:repo_pull_files) { |repository, number, options| gh_pull_files_path(**RepositoryUrls.segments(repository), number: number, **options) }
  direct(:repo_pull_file) { |repository, number, path, options| gh_pull_file_path(**RepositoryUrls.segments(repository), number: number, path: path, **options) }

  direct(:repo_tree) { |repository, options| RepositoryUrls.tree_path(self, repository, options) }
  direct(:repo_blob) { |repository, options| RepositoryUrls.blob_path(self, repository, options) }
end
