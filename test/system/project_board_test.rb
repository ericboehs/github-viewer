require "application_system_test_case"

# Drives a project board in a real browser, which is the only place the pages
# of items are actually assembled.
#
# `ProjectV2.items` has no filter argument, so a board is fetched a hundred
# items at a time and put together as the pages arrive - see
# ProjectsController#items and the project_board Stimulus controller. Nothing
# below the browser can tell whether that works.
class ProjectBoardTest < ApplicationSystemTestCase
  include ProjectPayloads

  setup do
    @user = User.create!(email_address: "board@example.com", password: "password123")
    @user.github_tokens.create!(domain: "github.com", token: "not-a-real-token")
    sign_in_as(@user)
    # Signing in is a form submit, and Capybara does not wait for it: without
    # this the first visit below can race the session being established.
    assert_no_current_path new_session_path
  end

  # Three pages of one item each, so the chaining has somewhere to go.
  def stub_pages(*pages)
    Github::ApiClient.any_instance.stubs(:fetch_project).returns(
      project(project_node(views: [ project_view(
        sort_by: [ { direction: "ASC", field: { name: "Title" } } ]
      ) ]))
    )
    Github::ApiClient.any_instance.stubs(:fetch_project_items).returns(*pages)
  end

  def page_of(nodes, has_next:)
    items_page(nodes, has_next: has_next, cursor: ("more" if has_next), total: 3)
  end

  test "items fetched after the page loads land in the right columns, in order" do
    stub_pages(
      page_of([ item_node(number: 1, title: "Charlie", values: { "Status" => "Todo" }) ], has_next: true),
      page_of([ item_node(number: 2, title: "Alpha", values: { "Status" => "Todo" }) ], has_next: true),
      page_of([ item_node(number: 3, title: "Bravo", values: { "Status" => "Done" }) ], has_next: false)
    )

    visit "/orgs/rails/projects/1"

    assert_text "3 items"

    # Alpha was fetched second but sorts first: the browser inserts each card
    # by its key rather than appending it.
    within "[data-column-for=todo]" do
      assert_equal %w[Alpha Charlie], all("article a").map(&:text)
      assert_text "2"
    end

    within "[data-column-for=done]" do
      assert_equal %w[Bravo], all("article a").map(&:text)
    end

    # The chunks take themselves off the page once they have been absorbed.
    assert_no_selector "[data-project-board-target=incoming]", visible: :all
    assert_no_text "Loading more items"
  end

  test "a column that only a later page needs is built as it arrives" do
    project = project(project_node(
      fields: [ { id: "f", name: "Team", dataType: "TEXT" } ],
      views: [ project_view(group_by: "Team") ]
    ))
    Github::ApiClient.any_instance.stubs(:fetch_project).returns(project)
    Github::ApiClient.any_instance.stubs(:fetch_project_items).returns(
      page_of([ item_node(number: 1, title: "First") ], has_next: true),
      page_of([ item_node(number: 2, title: "Second", values: { "Team" => "Platform" }) ], has_next: false)
    )

    visit "/orgs/rails/projects/1"

    assert_text "2 items"
    assert_selector "[data-column-for=platform] article a", text: "Second"
    assert_selector "[data-column-for=platform] [data-board-count]", text: "1"
  end

  test "a project board is accessible" do
    stub_pages(page_of([ item_node(number: 1, title: "Charlie", values: { "Status" => "Todo" }) ], has_next: false))

    visit "/orgs/rails/projects/1"

    assert_text "1 item"
    assert_accessible
  end

  test "a table view fills in its rows the same way" do
    Github::ApiClient.any_instance.stubs(:fetch_project).returns(
      project(project_node(views: [ project_view(layout: "TABLE_LAYOUT", fields: %w[Title Status]) ]))
    )
    Github::ApiClient.any_instance.stubs(:fetch_project_items).returns(
      page_of([ item_node(number: 1, title: "First", values: { "Status" => "Todo" }) ], has_next: true),
      page_of([ item_node(number: 2, title: "Second", values: { "Status" => "Done" }) ], has_next: false)
    )

    visit "/orgs/rails/projects/1"

    assert_text "2 items"
    assert_equal %w[First Second], all("tbody tr td a").map(&:text)
  end
end
