# frozen_string_literal: true

require "test_helper"

# Tests the Projects V2 half of Github::ApiClient. Projects have no REST
# endpoint at all, so every one of these goes through GraphQL.
class Github::ApiClientProjectsTest < ActiveSupport::TestCase
  include ProjectPayloads

  setup do
    @client = Github::ApiClient.new(token: "test_token")
  end

  # Records what the client posted, so the tests can assert on the query and
  # the variables as well as on what came back.
  def stub_graphql(response)
    posted = []
    transport = Object.new
    transport.define_singleton_method(:post) do |_path, body|
      posted << JSON.parse(body, symbolize_names: true)
      response.respond_to?(:call) ? response.call(posted.size) : response
    end
    transport.define_singleton_method(:rate_limit) { nil }
    @client.instance_variable_set(:@client, transport)

    posted
  end

  test "reads an organization's projects" do
    posted = stub_graphql({ data: { organization: { projectsV2: { nodes: [ project_node(number: 4) ] } } } })

    projects = @client.fetch_owner_projects("rails")

    assert_equal [ 4 ], projects.map(&:number)
    assert_includes posted.first[:query], "organization(login: $login)"
    assert_equal "rails", posted.first.dig(:variables, :login)
  end

  test "asks about a user when the owner is not an organization" do
    posted = stub_graphql({ data: { user: { projectsV2: { nodes: [ project_node ] } } } })

    assert_equal 1, @client.fetch_owner_projects("dhh", organization: false).size
    assert_includes posted.first[:query], "user(login: $login)"
  end

  test "reports an owner that does not exist" do
    stub_graphql({ data: { organization: nil } })

    assert_equal Github::ApiClient::ERROR_OWNER_NOT_FOUND, @client.fetch_owner_projects("nope")[:error]
  end

  test "reads the projects a repository is linked to" do
    stub_graphql({ data: { repository: { projectsV2: { nodes: [ project_node(title: "Roadmap") ] } } } })

    assert_equal [ "Roadmap" ], @client.fetch_repository_projects("rails", "rails").map(&:title)
  end

  test "reports a repository that does not exist" do
    stub_graphql({ data: { repository: nil } })

    error = @client.fetch_repository_projects("rails", "nope")[:error]

    assert_equal Github::ApiClient::ERROR_REPOSITORY_NOT_FOUND, error
  end

  test "reads one project with its fields and views" do
    stub_graphql({ data: { viewer: { login: "octocat" }, organization: { projectV2: project_node(number: 9) } } })

    project = @client.fetch_project("rails", "9")

    assert_equal 9, project.number
    assert_equal "octocat", project.viewer_login
    assert_equal "Status", project.fields.first.name
  end

  test "reads one project of a user rather than an organization" do
    posted = stub_graphql({ data: { viewer: { login: "dhh" }, user: { projectV2: project_node } } })

    assert_equal 1, @client.fetch_project("dhh", "1", organization: false).number
    assert_includes posted.first[:query], "user(login: $login)"
  end

  test "reports a project that does not exist" do
    stub_graphql({ data: { organization: { projectV2: nil } } })

    assert_equal Github::ApiClient::ERROR_PROJECT_NOT_FOUND, @client.fetch_project("rails", "404")[:error]
  end

  test "reads a page of items and passes the cursor along" do
    posted = stub_graphql({
      data: { node: { items: { totalCount: 2, pageInfo: { hasNextPage: true, endCursor: "next" },
                              nodes: [ item_node(number: 1) ] } } }
    })

    page = @client.fetch_project_items("PVT_1", after: "here", offset: 100)

    assert_equal 100, page.items.first.position
    assert_equal "next", page.end_cursor
    assert_equal "here", posted.first.dig(:variables, :after)
    assert_equal Github::ApiConfiguration::PROJECT_ITEMS_PAGE_SIZE, posted.first.dig(:variables, :first)
  end

  test "reports items asked of a project id that resolves to nothing" do
    stub_graphql({ data: { node: nil } })

    assert_equal Github::ApiClient::ERROR_PROJECT_NOT_FOUND, @client.fetch_project_items("PVT_x")[:error]
  end

  test "a GraphQL error is passed through rather than parsed" do
    stub_graphql({ errors: [ { message: "Your token has not been granted the required scopes" } ] })

    assert_match(/required scopes/, @client.fetch_owner_projects("rails")[:error])
    assert_match(/required scopes/, @client.fetch_repository_projects("rails", "rails")[:error])
    assert_match(/required scopes/, @client.fetch_project("rails", 1)[:error])
    assert_match(/required scopes/, @client.fetch_project_items("PVT_1")[:error])
  end
end
