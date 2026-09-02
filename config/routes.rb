Rails.application.routes.draw do
  resource :user, only: [ :show, :edit, :update ]
  get "dashboard/index"
  resource :session
  resources :passwords, param: :token
  resources :users, only: [ :new, :create ]
  resources :github_tokens, only: [ :create, :destroy ]
  resources :repositories, only: [ :index, :new, :create, :destroy ] do
    member do
      post :refresh
      get :assignable_users
      get :labels
    end
    resource :tree, only: [ :show ]
    resources :issues, only: [ :index, :show ] do
      collection do
        post :refresh
      end
      member do
        post :refresh
      end
    end
    resources :pulls, only: [ :index, :show ] do
      collection do
        post :refresh
      end
      member do
        post :refresh
        # Mirrors GitHub's own /pull/:number/commits and /files sub-pages
        get :commits
        get :files
        # The path is a query parameter rather than a path segment because file
        # paths contain slashes.
        get :file
      end
    end
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "dashboard#index"

  # Proxy-style issue viewing: /va.ghe.com/software/eert/issues/185 or /rails/rails/issues/123
  # Proxy URLs mirror GitHub's own, so a pasted link lands on the matching page
  # here: /issues/1 and /pull/1 on the issue view, /blob/ and /tree/ on the file
  # browser.
  # `format: false` because a file path ends in an extension that Rails would
  # otherwise strip as a response format, turning README.md into README.
  get "*path", to: "proxy#show", format: false, constraints: ->(req) {
    req.path.match?(%r{/(issues|pull)/\d+\z}) || req.path.match?(%r{/(blob|tree)/[^/]+})
  }
end
