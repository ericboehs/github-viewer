# frozen_string_literal: true

require "test_helper"

# Tests the components that draw a project: cards, rows, the two layouts, the
# view tabs and the chunks of items that arrive after the first page.
class ProjectComponentsTest < ViewComponent::TestCase
  include ProjectPayloads

  def layout_for(node = project_node(fields: [ single_select_field, number_field ]))
    parsed = project(node)

    Projects::Layout.for(project: parsed, view: parsed.default_view)
  end

  def card(item, layout: layout_for)
    render_inline(ProjectCardComponent.new(item: item, layout: layout))
  end

  # --- cards -----------------------------------------------------------------

  test "a card links to the issue in this application and names its repository" do
    card(project_items(item_node(number: 12, title: "Ship it")).first)

    assert_selector "a[href='/rails/rails/issues/12']", text: "Ship it"
    assert_text "rails/rails #12"
  end

  test "a card for a pull request links to the pull request page" do
    card(project_items(item_node(number: 12, typename: "PullRequest")).first)

    assert_selector "a[href='/rails/rails/pull/12']"
  end

  test "a draft issue has nowhere to link to and says what it is" do
    card(project_items(item_node(typename: "DraftIssue", title: "An idea")).first)

    assert_no_selector "a"
    assert_text "An idea"
    assert_text "Draft"
  end

  test "a card shows labels, assignees and field values" do
    item = project_items(
      item_node(labels: %w[bug], assignees: %w[octocat], values: { "Estimate" => 3.0 })
    ).first

    card(item)

    assert_text "bug"
    assert_selector "img[alt=octocat]", count: 1
    # 3.0 from GraphQL is an estimate of three, not of three point zero.
    assert_selector "dd", text: "3"
    assert_selector "dt", text: "Estimate", visible: :all
  end

  test "a card does not repeat the column it is sitting in" do
    card(project_items(item_node(values: { "Status" => "Todo", "Estimate" => 1 })).first)

    assert_no_selector "dd", text: "Todo"
    assert_selector "dd", text: "1"
  end

  # The browser compares these keys as strings, because that is all a DOM
  # attribute is, so the order has to survive being written down.
  test "a card carries a sort key that orders it against cards not fetched yet" do
    layout = layout_for(project_node(
      fields: [ single_select_field ],
      views: [ project_view(sort_by: [ { direction: "ASC", field: { name: "Status" } } ]) ]
    ))
    early, late = project_items(
      item_node(number: 1, values: { "Status" => "Todo" }),
      item_node(number: 2, values: { "Status" => "Done" })
    )

    card(late, layout: layout)
    late_key = page.find("article")["data-sort-key"]
    card(early, layout: layout)
    early_key = page.find("article")["data-sort-key"]

    # Todo first, even though it was rendered second and sorts second by name.
    assert early_key < late_key, "expected #{early_key} to sort before #{late_key}"
  end

  test "a card shows only as many field values and faces as fit" do
    fields = (1..6).map { |index| number_field(name: "N#{index}") }
    values = (1..6).to_h { |index| [ "N#{index}", index ] }
    layout = layout_for(project_node(fields: fields, views: [ project_view(group_by: nil) ]))

    card(project_items(item_node(values: values, assignees: %w[a b c d e])).first, layout: layout)

    assert_selector "dd", count: ProjectCardComponent::MAX_CHIPS
    assert_selector "img", count: ProjectCardComponent::MAX_AVATARS
  end

  test "a card shows a value whose field the project no longer defines" do
    # A field can be deleted from a project while its values linger on items.
    card(project_items(item_node(values: { "Status" => "Todo", "Ghost" => "boo", "Blank" => "" })).first)

    assert_selector "dd", text: "boo"
    assert_no_selector "dt", text: "Blank", visible: :all
  end

  test "a board with nothing to group by is one column of everything" do
    layout = layout_for(project_node(fields: [ number_field ], views: []))
    items = project_items(item_node(number: 1), item_node(number: 2))

    render_inline(ProjectBoardComponent.new(layout: layout, items: items))

    assert_selector "[data-column-for='#{Projects::Board::UNGROUPED}'] article", count: 2
    assert_text "All items"
  end

  test "a table says it is still filling up below its rows, not among them" do
    layout = Projects::Layout.for(project: project(project_node(fields: [ single_select_field ])))

    render_inline(ProjectTableComponent.new(layout: layout, items: [], loading: true))

    assert_selector "[data-column-loading]:not([hidden])"
    assert_no_selector "tbody [data-column-loading]"
  end

  test "a table with no view falls back to the project's own fields" do
    layout = Projects::Layout.for(project: project(project_node(fields: [ single_select_field ])))

    render_inline(ProjectTableComponent.new(layout: layout, items: []))

    assert_equal %w[Title Status], page.all("thead th").map(&:text).map(&:strip)
  end

  # --- boards ----------------------------------------------------------------

  test "a board draws every column of its field, empty ones included" do
    layout = layout_for
    items = project_items(item_node(number: 1, values: { "Status" => "Todo" }))

    render_inline(ProjectBoardComponent.new(layout: layout, items: items))

    assert_selector "[data-column-for=todo] [data-cards-for=todo] article", count: 1
    assert_selector "[data-column-for=done] [data-board-count]", text: "0"
    assert_selector "template[data-project-board-target=columnTemplate]", visible: :all
  end

  test "a column past its limit shows the first cards and offers the rest" do
    layout = layout_for
    over = ProjectBoardComponent::VISIBLE_LIMIT + 3
    items = project_items(*(1..over).map { |n| item_node(number: n, values: { "Status" => "Todo" }) })

    render_inline(ProjectBoardComponent.new(layout: layout, items: items))

    # Every card is rendered - expanding is instant, and later pages of items
    # have to be able to find their place among them.
    assert_selector "[data-cards-for=todo] article", count: over, visible: :all
    assert_selector "[data-cards-for=todo] article:not([hidden])", count: ProjectBoardComponent::VISIBLE_LIMIT
    assert_selector "[data-column-for=todo] [data-column-expand]", text: "Show 3 more"
    # The header still counts the whole column.
    assert_selector "[data-column-for=todo] [data-board-count]", text: over.to_s
  end

  test "a column within its limit offers nothing to expand" do
    layout = layout_for
    items = project_items(item_node(number: 1, values: { "Status" => "Todo" }))

    render_inline(ProjectBoardComponent.new(layout: layout, items: items))

    assert_no_selector "[data-column-expand]:not([hidden])"
    assert_no_selector "article[hidden]", visible: :all
  end

  test "every column says it is still filling up while pages are on their way" do
    layout = layout_for
    items = project_items(item_node(number: 1, values: { "Status" => "Todo" }))

    render_inline(ProjectBoardComponent.new(layout: layout, items: items, loading: true))

    # In every column, because which one the next page fills is not yet known,
    # and outside the cards container, because what is in there is counted.
    assert_selector "[data-column-for=todo] [data-column-loading]:not([hidden])"
    assert_selector "[data-column-for=done] [data-column-loading]:not([hidden])"
    assert_no_selector "[data-cards-for] [data-column-loading]"
  end

  test "the last page of items leaves no column claiming to be loading" do
    layout = layout_for

    render_inline(ProjectBoardComponent.new(layout: layout, items: [], loading: false))

    assert_no_selector "[data-column-loading]:not([hidden])"
  end

  # --- tables ----------------------------------------------------------------

  test "a table shows the columns the view saved, in order" do
    node = project_node(
      fields: [ single_select_field, number_field ],
      views: [ project_view(layout: "TABLE_LAYOUT", fields: %w[Status Estimate]) ]
    )
    item = project_items(item_node(number: 3, title: "Ship", values: { "Status" => "Todo", "Estimate" => 2 })).first

    render_inline(ProjectTableComponent.new(layout: layout_for(node), items: [ item ]))

    assert_equal %w[Title Status Estimate], page.all("thead th").map(&:text).map(&:strip)
    assert_selector "tbody tr td a", text: "Ship"
    assert_text "#3"
    assert_selector "tbody span", text: "Todo"
    assert_text "2"
  end

  test "a table can show facets of the item that are not project fields" do
    node = project_node(views: [ project_view(layout: "TABLE_LAYOUT", fields: %w[Repository Labels Assignees]) ])
    item = project_items(item_node(labels: %w[bug ui], assignees: %w[octocat])).first

    render_inline(ProjectTableComponent.new(layout: layout_for(node), items: [ item ]))

    assert_text "rails/rails"
    assert_text "bug, ui"
    assert_text "octocat"
  end

  test "a draft issue in a table has nowhere to link to either" do
    node = project_node(views: [ project_view(layout: "TABLE_LAYOUT", fields: %w[Title Repository]) ])
    item = project_items(item_node(typename: "DraftIssue", title: "An idea")).first

    render_inline(ProjectTableComponent.new(layout: layout_for(node), items: [ item ]))

    assert_no_selector "tbody a"
    assert_text "An idea"
  end

  test "a table view with no saved fields falls back to the project's own" do
    node = project_node(fields: [ single_select_field, number_field ],
                        views: [ project_view(layout: "TABLE_LAYOUT", fields: []) ])

    render_inline(ProjectTableComponent.new(layout: layout_for(node), items: []))

    assert_equal %w[Title Status Estimate], page.all("thead th").map(&:text).map(&:strip)
  end

  # --- chunks ----------------------------------------------------------------

  test "a chunk of a board tags its items with the column they belong in" do
    items = project_items(item_node(number: 1, values: { "Status" => "Todo" }), item_node(number: 2))

    render_inline(ProjectChunkComponent.new(layout: layout_for, items: items, complete: false))

    assert_selector "[data-project-board-target=incoming][data-complete=false]", visible: :all
    assert_selector "[data-column-key=todo] article", count: 1, visible: :all
    assert_selector "[data-column-key='#{Projects::Board::NO_VALUE}'] article", count: 1, visible: :all
  end

  test "a chunk of a table is a table, so the rows survive being parsed" do
    node = project_node(views: [ project_view(layout: "TABLE_LAYOUT") ])

    render_inline(ProjectChunkComponent.new(layout: layout_for(node), items: project_items(item_node), complete: true))

    assert_selector "table tbody[data-column-key='#{ProjectTableComponent::ROWS}'] tr", visible: :all
  end

  test "an empty chunk renders nothing unless it is the last one" do
    layout = layout_for

    render_inline(ProjectChunkComponent.new(layout: layout, items: [], complete: false))
    assert_no_selector "[data-project-board-target=incoming]", visible: :all

    render_inline(ProjectChunkComponent.new(layout: layout, items: [], complete: true))
    assert_selector "[data-project-board-target=incoming]", visible: :all
  end

  # --- view tabs -------------------------------------------------------------

  test "the view tabs mark the one being shown and link to the others" do
    parsed = project(project_node(views: [
      project_view(number: 1, name: "Board"),
      project_view(number: 2, name: "Table", layout: "TABLE_LAYOUT")
    ]))

    render_inline(ProjectViewTabsComponent.new(project: parsed, current: parsed.default_view))

    assert_selector "a[aria-current=page]", text: "Board"
    assert_selector "a[href='/orgs/rails/projects/1/views/2']", text: "Table"
  end

  test "a project with one view has no tabs worth drawing" do
    parsed = project(project_node(views: [ project_view ]))

    render_inline(ProjectViewTabsComponent.new(project: parsed, current: parsed.default_view))

    assert_no_selector "nav"
  end

  # --- the list of projects --------------------------------------------------

  test "a closed or private project is marked as such" do
    node = project_node.merge(closed: true, public: false)

    render_inline(ProjectListItemComponent.new(project: project(node)))

    assert_text "Closed"
    assert_text "Private"
  end
end
