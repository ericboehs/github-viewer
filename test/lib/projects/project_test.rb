# frozen_string_literal: true

require "test_helper"

# Tests the parsing of GraphQL project payloads: Projects::Project,
# Projects::View, Projects::Field and Projects::ItemBuilder.
class Projects::ProjectTest < ActiveSupport::TestCase
  include ProjectPayloads

  test "reads a project, its owner and its host" do
    parsed = project(project_node(number: 7, title: "Roadmap", owner: "rails"))

    assert_equal 7, parsed.number
    assert_equal "Roadmap", parsed.title
    assert_equal "rails", parsed.owner_login
    assert_equal "orgs", parsed.owner_type
    assert_equal "github.com", parsed.github_domain
    assert_equal "octocat", parsed.viewer_login
    assert_equal 3, parsed.item_count
    assert_equal Time.utc(2025, 1, 2, 3, 4, 5), parsed.updated_at
  end

  test "a user's project points at the users path rather than the orgs one" do
    parsed = project(project_node(owner: "dhh", owner_type: "User"))

    assert_equal "users", parsed.owner_type
  end

  test "an owner type GitHub did not name falls back to an organization" do
    assert_equal "orgs", ProjectUrls.owner_type_for(nil)
    assert ProjectUrls.organization?("orgs")
    assert_not ProjectUrls.organization?("users")
  end

  test "reads single-select options and iteration configuration" do
    node = project_node(fields: [
      single_select_field(options: %w[Todo Done]),
      iteration_field(iterations: [ iteration(title: "S2") ], completed: [ iteration(title: "S1") ])
    ])
    parsed = project(node)

    status = parsed.field("status")
    assert status.single_select?
    assert_equal %w[Todo Done], status.values
    assert_equal "GREEN", status.option("todo").color

    sprint = parsed.field("Sprint")
    assert sprint.iteration?
    # A completed iteration is still a value an item can hold, but it is not a
    # column anyone wants on a board.
    assert_equal [ "S2" ], sprint.values
    assert_equal 2, sprint.iterations.size
    assert_equal "S2", sprint.current_iteration.title
  end

  test "an iteration with no start date is never the current one" do
    field = Projects::Field.from_graphql(iteration_field(iterations: [ { id: "x", title: "S", duration: 14 } ]))

    assert_nil field.current_iteration
    assert_nil field.iterations.first.range
  end

  test "a field type the query did not ask about is skipped rather than half-read" do
    parsed = project(project_node(fields: [ single_select_field, {} ]))

    assert_equal 1, parsed.fields.size
  end

  test "finds a field by the way a filter would spell it" do
    parsed = project(project_node(fields: [ single_select_field(name: "Sub status") ]))

    assert_equal "Sub status", parsed.field_for_key("sub-status").name
    assert_equal "Sub status", parsed.field_for_key("SUB STATUS").name
    assert_nil parsed.field_for_key("nope")
    assert_nil parsed.field(nil)
  end

  test "reads a view's layout, filter, grouping and sort" do
    node = project_node(views: [
      project_view(number: 1, name: "Board", filter: "is:open"),
      project_view(number: 2, name: "Table", layout: "TABLE_LAYOUT", fields: %w[Title Status Estimate])
    ])
    parsed = project(node)

    board, table = parsed.views

    assert board.board?
    assert_not board.table?
    assert_equal "is:open", board.filter
    assert_equal "Status", board.grouping
    assert table.table?
    assert_equal %w[Title Status Estimate], table.field_names
    assert_equal 2, parsed.view("2").number
    assert_nil parsed.view(nil)
    assert_equal 1, parsed.default_view.number
  end

  test "a roadmap is rendered as a table rather than not at all" do
    parsed = project(project_node(views: [ project_view(layout: "ROADMAP_LAYOUT") ]))

    assert parsed.default_view.table?
  end

  test "builds an issue item with its labels, assignees and field values" do
    item = project_items(
      item_node(number: 12, title: "Ship", labels: %w[bug], assignees: %w[octocat], values: { "Status" => "Todo" })
    ).first

    assert item.issue?
    assert item.open?
    assert_equal 12, item.number
    assert_equal "rails/rails", item.repository
    assert_equal %w[bug], item.label_names
    assert_equal %w[octocat], item.assignee_logins
    assert_equal "Todo", item.field_value("Status")
    assert_equal "octocat", item.author[:login]
    assert_equal 0, item.position
  end

  test "distinguishes merged, draft and closed" do
    merged, draft, closed, draft_issue = project_items(
      item_node(number: 1, typename: "PullRequest", state: "MERGED", merged: true),
      item_node(number: 2, typename: "PullRequest", draft: true),
      item_node(number: 3, state: "CLOSED"),
      item_node(number: 4, typename: "DraftIssue", title: "Just an idea")
    )

    assert merged.merged?
    assert merged.closed?
    assert_equal "draft", draft.state
    assert closed.closed?
    assert draft_issue.draft_issue?
    assert_nil draft_issue.number
    assert_nil draft_issue.url
    assert_equal "Just an idea", draft_issue.title
  end

  test "an item whose content was deleted is dropped" do
    page = items_page([ { id: "PVTI_x", content: nil }, item_node(number: 1) ])

    assert_equal 1, page.items.size
  end

  test "the Title field is not repeated as a field value" do
    item = project_items(item_node(values: { "Title" => "Ship", "Status" => "Todo" })).first

    assert_equal({ "Status" => "Todo" }, item.fields)
  end

  test "a page carries the cursor for the next one" do
    page = items_page([ item_node ], has_next: true, cursor: "abc", total: 250)

    assert page.has_next_page
    assert_equal "abc", page.end_cursor
    assert_equal 250, page.total_count
  end

  test "positions continue across pages so the project's order survives" do
    page = Projects::Page.from_graphql(
      { totalCount: 2, pageInfo: {}, nodes: [ item_node(number: 5) ] }, offset: 100
    )

    assert_equal 100, page.items.first.position
  end

  test "a field that enumerates nothing has no values to make columns from" do
    parsed = project(project_node(fields: [ number_field ]))

    assert_empty parsed.field("Estimate").values
    assert_not parsed.field("Estimate").enumerated?
  end

  test "a view or an item GitHub answered without the optional parts is still read" do
    bare = project_view.merge(fields: nil, groupByFields: nil, verticalGroupByFields: nil, sortByFields: nil)
    parsed = project(project_node(views: [ bare ]))
    view = parsed.default_view

    assert_empty view.field_names
    assert_nil view.grouping
    assert_empty view.sort_by

    item = items_page([ item_node(number: 1).except(:fieldValues) ]).items.first

    assert_empty item.fields
  end

  test "a project GitHub has never touched has no update time" do
    parsed = project(project_node.merge(updatedAt: nil))

    assert_nil parsed.updated_at
  end

  test "a view field GitHub returned without a name is left out" do
    parsed = project(project_node(views: [ project_view(layout: "TABLE_LAYOUT").merge(
      fields: { nodes: [ { name: "Title" }, { name: "" } ] }
    ) ]))

    assert_equal [ "Title" ], parsed.default_view.field_names
  end

  test "a field value of a type the query did not ask about is skipped" do
    page = items_page([ item_node(number: 1).merge(
      fieldValues: { nodes: [
        { __typename: "ProjectV2ItemFieldUserValue", field: { name: "Reviewers" } },
        { __typename: "ProjectV2ItemFieldSingleSelectValue", field: { name: "" } },
        { __typename: "ProjectV2ItemFieldSingleSelectValue", name: nil, field: { name: "Status" } }
      ] }
    ) ])

    assert_empty page.items.first.fields
  end

  test "an item with no author has none rather than an empty one" do
    node = item_node(number: 1)
    node[:content][:author] = nil

    assert_nil items_page([ node ]).items.first.author
  end

  test "a page with nothing in it is a page all the same" do
    assert_empty Projects::Page::EMPTY.items
    assert_not Projects::Page::EMPTY.has_next_page
  end
end
