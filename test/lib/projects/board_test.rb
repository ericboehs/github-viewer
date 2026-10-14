# frozen_string_literal: true

require "test_helper"

# Tests Projects::Board, which decides a board's columns and which one each
# item lands in.
class Projects::BoardTest < ActiveSupport::TestCase
  include ProjectPayloads

  test "columns are the grouping field's own values, in the project's order, then the empty one" do
    board = Projects::Board.new(project: project, view: nil)

    assert_equal [ "Todo", "Done", "No Status" ], board.columns.map(&:name)
    assert board.enumerated?
  end

  test "an item with no value for the field lands in the empty column" do
    board = Projects::Board.new(project: project)

    assert_equal "No Status", board.column_of(project_items(item_node).first).name
    assert_equal "Todo", board.column_of(project_items(item_node(values: { "Status" => "Todo" })).first).name
  end

  test "grouping follows the view rather than assuming Status" do
    node = project_node(
      fields: [ single_select_field, single_select_field(name: "Priority", options: %w[P1 P2]) ],
      views: [ project_view(group_by: "Priority") ]
    )
    project = project(node)

    board = Projects::Board.new(project: project, view: project.default_view)

    assert_equal "Priority", board.field_name
    assert_equal [ "P1", "P2", "No Priority" ], board.columns.map(&:name)
  end

  test "a column's colour comes from the option, and the empty one is grey" do
    board = Projects::Board.new(project: project)
    todo, _done, none = board.columns

    assert_includes todo.css_class, "green"
    assert_equal Projects::Option::DEFAULT_CLASS, none.css_class
  end

  test "grouping by a field that does not enumerate its values discovers columns from the items" do
    node = project_node(fields: [ { id: "f", name: "Notes", dataType: "TEXT" } ],
                        views: [ project_view(group_by: "Notes") ])
    project = project(node)
    board = Projects::Board.new(project: project, view: project.default_view)

    assert_not board.enumerated?
    assert_equal [ "No Notes" ], board.columns.map(&:name)

    groups = board.group(project_items(item_node(values: { "Notes" => "later" })))

    assert_equal [ "No Notes", "later" ], groups.map { |column, _items| column.name }
  end

  test "a project with no grouping field at all is one column" do
    project = project(project_node(fields: [ number_field ], views: [ project_view(group_by: nil) ]))
    board = Projects::Board.new(project: project)

    assert_not board.enumerated?
    assert_nil board.field_name
    assert_equal [ "All items" ], board.columns.map(&:name)
    assert_equal "All items", board.column_of(project_items(item_node).first).name
  end

  test "grouping keeps empty known columns and puts items in the right ones" do
    items = project_items(item_node(number: 1, values: { "Status" => "Todo" }), item_node(number: 2))
    groups = Projects::Board.new(project: project).group(items)

    assert_equal [ "Todo", "Done", "No Status" ], groups.map { |column, _items| column.name }
    assert_equal [ [ 1 ], [], [ 2 ] ], groups.map { |_column, column_items| column_items.map(&:number) }
  end

  test "a column key survives being put in an attribute" do
    project = project(project_node(fields: [ single_select_field(options: [ "In Progress" ]) ]))
    board = Projects::Board.new(project: project)

    assert_equal "in-progress", board.columns.first.key
  end
end
