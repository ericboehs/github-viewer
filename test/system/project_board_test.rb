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

  # Clicks a column's expand button, and says so only once the button has
  # taken itself away.
  #
  # The click is dispatched from inside the page rather than through Selenium's
  # pointer, which on this board delivers nothing at all about a quarter of the
  # time - no pointerdown, no click, no error, in a document that is otherwise
  # alive and has the button at the coordinates it was clicked at. Whatever
  # ails the input pipeline here, it is not the application: this still goes
  # through the button's Stimulus action, which is the part worth testing.
  def expand_column(key)
    button = "[data-column-for=#{key}] [data-column-expand]"

    page.execute_script("arguments[0].click()", find(button))

    assert_no_selector "#{button}:not([hidden])"
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

    # The chunks take themselves off the page once they have been absorbed,
    # and nothing is left claiming that more items are coming.
    assert_no_selector "[data-project-board-target=incoming]", visible: :all
    assert_no_selector "[data-column-loading]:not([hidden])"
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
    # A column built in the browser stops saying it is loading along with the
    # ones that were drawn with the page.
    assert_no_selector "[data-column-loading]:not([hidden])"
    assert_selector "[data-column-for=platform] article a", text: "Second"
    assert_selector "[data-column-for=platform] [data-board-count]", text: "1"
  end

  test "a column keeps to its limit as pages arrive, until it is expanded" do
    limit = ProjectBoardComponent::VISIBLE_LIMIT
    first = (1..limit).map { |n| item_node(number: n, title: "Item #{format('%03d', n)}", values: { "Status" => "Todo" }) }
    second = ((limit + 1)..(limit + 5)).map { |n| item_node(number: n, title: "Item #{format('%03d', n)}", values: { "Status" => "Todo" }) }

    stub_pages(
      items_page(first, has_next: true, cursor: "more", total: limit + 5),
      items_page(second, has_next: false, total: limit + 5)
    )

    visit "/orgs/rails/projects/1"

    assert_text "#{limit + 5} items"

    within "[data-column-for=todo]" do
      assert_selector "article:not([hidden])", count: limit
      assert_selector "[data-board-count]", text: (limit + 5).to_s
      assert_selector "[data-column-expand]", text: "Show 5 more"
    end

    expand_column("todo")

    assert_selector "[data-column-for=todo] article:not([hidden])", count: limit + 5
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
