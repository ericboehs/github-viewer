# frozen_string_literal: true

require "test_helper"

# Tests ProjectsController: an owner's projects, a repository's linked
# projects, and a project's board or table with its items paged in.
class ProjectsControllerTest < ActionDispatch::IntegrationTest
  include ProjectPayloads

  setup do
    @user = User.create!(email_address: "projects@example.com", password: "password123")
    @user.github_tokens.create!(domain: "github.com", token: "ghp_testtesttesttesttest")
    @repository = @user.repositories.create!(
      github_domain: "github.com", owner: "rails", name: "rails", full_name: "rails/rails",
      url: "https://github.com/rails/rails", default_branch: "main", cached_at: 1.hour.ago
    )
    sign_in_as(@user)
  end

  def stub_project(project = project(), items: [], pages: nil)
    Github::ApiClient.any_instance.stubs(:fetch_project).returns(project)
    Github::ApiClient.any_instance.stubs(:fetch_project_items).returns(*(pages || [ items_page(items) ]))
  end

  # --- an owner's projects ---------------------------------------------------

  test "lists an organization's projects" do
    Github::ApiClient.any_instance.expects(:fetch_owner_projects).with("rails", organization: true)
      .returns([ project(project_node(number: 4, title: "Roadmap")) ])

    get "/orgs/rails/projects"

    assert_response :success
    assert_select "a[href=?]", "/orgs/rails/projects/4", text: /Roadmap/
    assert_select "p", text: "3 items"
  end

  test "lists a user's projects" do
    Github::ApiClient.any_instance.expects(:fetch_owner_projects).with("dhh", organization: false)
      .returns([ project(project_node(owner: "dhh", owner_type: "User")) ])

    get "/users/dhh/projects"

    assert_response :success
    assert_select "a[href=?]", "/users/dhh/projects/1"
  end

  test "an owner with no projects says so" do
    Github::ApiClient.any_instance.stubs(:fetch_owner_projects).returns([])

    get "/orgs/rails/projects"

    assert_response :success
    assert_select "p", text: /has no projects/
  end

  test "an API failure leaves the page standing with the reason on it" do
    Github::ApiClient.any_instance.stubs(:fetch_owner_projects).returns({ error: "Bad credentials" })

    get "/orgs/rails/projects"

    assert_response :success
    assert_select "div", text: /Bad credentials/
  end

  test "no token for the host is reported rather than raised" do
    @user.github_tokens.destroy_all

    get "/orgs/rails/projects"

    assert_response :success
    assert_select "div", text: /No GitHub token/
  end

  test "naming github.com in the path redirects to the shorter form" do
    get "/github.com/orgs/rails/projects"

    assert_redirected_to "/orgs/rails/projects"
    assert_response :moved_permanently
  end

  test "an enterprise host keeps its segment" do
    @user.github_tokens.create!(domain: "va.ghe.com", token: "ghp_enterprisetokenvalue")
    Github::ApiClient.any_instance.expects(:fetch_owner_projects)
      .returns([ project(project_node(owner: "software"), domain: "va.ghe.com") ])

    get "/va.ghe.com/orgs/software/projects"

    assert_response :success
    assert_select "a[href=?]", "/va.ghe.com/orgs/software/projects/1"
  end

  # --- a repository's linked projects ---------------------------------------

  test "a repository's Projects tab lists the projects it is linked to" do
    Github::ApiClient.any_instance.expects(:fetch_repository_projects).with("rails", "rails")
      .returns([ project(project_node(title: "Roadmap")) ])

    get repo_projects_path(@repository)

    assert_response :success
    assert_select "a[href=?]", "/orgs/rails/projects/1", text: /Roadmap/
    assert_select "nav a[aria-current=page]", text: "Projects"
  end

  test "a repository linked to nothing says so" do
    Github::ApiClient.any_instance.stubs(:fetch_repository_projects).returns([])

    get repo_projects_path(@repository)

    assert_select "p", text: /not linked to any projects/
  end

  # --- one project -----------------------------------------------------------

  test "renders a board grouped by the view's field, with the items in it" do
    stub_project(items: [
      item_node(number: 1, title: "First", values: { "Status" => "Todo" }),
      item_node(number: 2, title: "Second")
    ])

    get "/orgs/rails/projects/1"

    assert_response :success
    assert_select "[data-column-for=todo] [data-board-count]", text: "1"
    assert_select "[data-column-for=todo] a", text: /First/
    assert_select "[data-column-for='#{Projects::Board::NO_VALUE}'] a", text: /Second/
    assert_select "[data-column-for=done] [data-board-count]", text: "0"
  end

  test "a card links into this application rather than out to GitHub" do
    stub_project(items: [ item_node(number: 12, typename: "PullRequest") ])

    get "/orgs/rails/projects/1"

    assert_select "a[href=?]", "/rails/rails/pull/12"
  end

  test "renders a table view with the columns the view saved" do
    project = project(project_node(
      fields: [ single_select_field, number_field ],
      views: [ project_view(name: "All", layout: "TABLE_LAYOUT", fields: %w[Title Status Estimate]) ]
    ))
    stub_project(project, items: [ item_node(number: 1, values: { "Status" => "Todo", "Estimate" => 3 }) ])

    get "/orgs/rails/projects/1"

    assert_response :success
    assert_select "table thead th", text: "Estimate"
    assert_select "table tbody tr td", text: "Todo"
  end

  test "offers the project's saved views as tabs" do
    project = project(project_node(views: [
      project_view(number: 1, name: "Board"),
      project_view(number: 2, name: "Table", layout: "TABLE_LAYOUT")
    ]))
    stub_project(project)

    get "/orgs/rails/projects/1"

    assert_select "a[aria-current=page]", text: "Board"
    assert_select "a[href=?]", "/orgs/rails/projects/1/views/2", text: "Table"
  end

  test "a view in the path is the one rendered" do
    project = project(project_node(views: [
      project_view(number: 1, name: "Board"),
      project_view(number: 2, name: "Table", layout: "TABLE_LAYOUT")
    ]))
    stub_project(project)

    get "/orgs/rails/projects/1/views/2"

    assert_select "table"
    assert_select "a[aria-current=page]", text: "Table"
  end

  test "the filter box starts out holding the view's own filter" do
    stub_project(project(project_node(views: [ project_view(filter: "is:open") ])))

    get "/orgs/rails/projects/1"

    assert_select "input[name=q][value=?]", "is:open"
  end

  test "a filter in the query string narrows the items and replaces the view's own" do
    stub_project(
      project(project_node(views: [ project_view(filter: "is:open") ])),
      items: [ item_node(number: 1, title: "Keep", values: { "Status" => "Todo" }),
              item_node(number: 2, title: "Drop", values: { "Status" => "Done" }) ]
    )

    get "/orgs/rails/projects/1", params: { q: "status:Todo" }

    assert_select "a", text: /Keep/
    assert_select "a", { text: /Drop/, count: 0 }
    assert_select "input[name=q][value=?]", "status:Todo"
    assert_select "span", text: "1 item"
  end

  test "an empty filter box clears the view's filter rather than restoring it" do
    stub_project(
      project(project_node(views: [ project_view(filter: "status:Todo") ])),
      items: [ item_node(number: 2, title: "Drop", values: { "Status" => "Done" }) ]
    )

    get "/orgs/rails/projects/1", params: { q: "" }

    assert_select "a", text: /Drop/
  end

  test "a filter naming a field the project does not have says so" do
    stub_project

    get "/orgs/rails/projects/1", params: { q: "nonsense:1" }

    assert_select "div", text: /no field called: nonsense/
  end

  test "a project that cannot be read sends the reader back to the owner's projects" do
    Github::ApiClient.any_instance.stubs(:fetch_project).returns({ error: "Project not found" })

    get "/orgs/rails/projects/404"

    assert_redirected_to "/orgs/rails/projects"
    assert_equal "Project not found", flash[:alert]
  end

  test "items that failed to load leave the board empty rather than broken" do
    Github::ApiClient.any_instance.stubs(:fetch_project).returns(project)
    Github::ApiClient.any_instance.stubs(:fetch_project_items).returns({ error: "Bad credentials" })

    get "/orgs/rails/projects/1"

    assert_response :success
    assert_select "div", text: /Bad credentials/
    assert_select "span", text: "0 items"
  end

  test "a project with no saved views is one board of everything" do
    stub_project(project(project_node(fields: [ number_field ], views: [])),
                items: [ item_node(number: 1) ])

    get "/orgs/rails/projects/1"

    assert_response :success
    assert_select "[data-column-for='#{Projects::Board::UNGROUPED}'] article"
    assert_select "nav a[aria-current=page]", { text: "Board", count: 0 }
  end

  # --- items arriving a page at a time --------------------------------------

  test "a first page that is not the last leaves a frame for the next" do
    stub_project(pages: [ items_page([ item_node(number: 1) ], has_next: true, cursor: "c1", total: 200) ])

    get "/orgs/rails/projects/1"

    assert_select "turbo-frame#project-chunk-2[src=?]",
      "/orgs/rails/projects/1/items?after=c1&offset=1&page=2"
  end

  test "a later page renders its items hidden, labelled with the column they belong in" do
    stub_project(pages: [ items_page([ item_node(number: 2, values: { "Status" => "Done" }) ]) ])

    get "/orgs/rails/projects/1/items", params: { page: 2, after: "c1", offset: 100 }

    assert_response :success
    assert_select "turbo-frame#project-chunk-2 [data-project-board-target=incoming][data-complete=true]"
    assert_select "[data-column-key=done] a"
    assert_select "turbo-frame#project-chunk-3", count: 0
  end

  test "a later page carries the filter and the view forward" do
    project = project(project_node(views: [ project_view(number: 1), project_view(number: 2, name: "T", layout: "TABLE_LAYOUT") ]))
    stub_project(project, pages: [ items_page([ item_node(number: 1) ], has_next: true, cursor: "c2") ])

    get "/orgs/rails/projects/1/items", params: { page: 2, after: "c1", offset: 100, q: "is:open", view_number: 2 }

    assert_response :success
    # A table view's rows arrive in a table of their own; a `<tr>` in a `<div>`
    # would be hoisted out of it by the parser.
    assert_select "table[data-project-board-target=incoming] tbody[data-column-key=rows] tr"
    assert_select "turbo-frame#project-chunk-3[src*=?]", "q=is%3Aopen"
    assert_select "turbo-frame#project-chunk-3[src*=?]", "view_number=2"
  end

  test "a page of items that the filter emptied still chains to the next" do
    stub_project(pages: [ items_page([ item_node(values: { "Status" => "Done" }) ], has_next: true, cursor: "c2") ])

    get "/orgs/rails/projects/1/items", params: { page: 2, after: "c1", offset: 100, q: "status:Todo" }

    assert_select "[data-project-board-target=incoming]", count: 0
    assert_select "turbo-frame#project-chunk-3"
  end

  test "a project too large to walk stops and says so" do
    stub_project(pages: [ items_page([ item_node ], has_next: true, cursor: "c") ])

    get "/orgs/rails/projects/1/items", params: { page: Projects::Chunk::MAX_PAGES, after: "c", offset: 1900 }

    assert_select "turbo-frame#project-chunk-#{Projects::Chunk::MAX_PAGES + 1}", count: 0
  end

  test "a frame asking for a project that has gone away returns nothing at all" do
    Github::ApiClient.any_instance.stubs(:fetch_project).returns({ error: "Project not found" })

    get "/orgs/rails/projects/1/items", params: { page: 2, after: "c1" }

    assert_response :no_content
  end

  # --- the shape of a project is read once, its items every time -------------

  test "paging items does not re-read the project on every request" do
    cache = ActiveSupport::Cache::MemoryStore.new
    Rails.stubs(:cache).returns(cache)
    Github::ApiClient.any_instance.expects(:fetch_project).once.returns(project)
    Github::ApiClient.any_instance.stubs(:fetch_project_items).returns(items_page([]))

    get "/orgs/rails/projects/1"
    get "/orgs/rails/projects/1/items", params: { page: 2, after: "c1" }

    assert_response :success
  end

  test "signed out, a project page asks for a sign in" do
    delete session_path

    get "/orgs/rails/projects/1"

    assert_redirected_to new_session_path
  end
end
