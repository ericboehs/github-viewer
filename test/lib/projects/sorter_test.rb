# frozen_string_literal: true

require "test_helper"

# Tests Projects::Sorter, which gives each item a key the browser can insert it
# by - items arrive over several requests, so they cannot be sorted in one go
# on the server.
class Projects::SorterTest < ActiveSupport::TestCase
  include ProjectPayloads

  def sorter_for(sort_by, fields: [ single_select_field, number_field ])
    project = project(project_node(fields: fields, views: [ project_view(sort_by: sort_by) ]))

    Projects::Sorter.new(project: project, view: project.default_view)
  end

  def sort(sorter, items)
    directions = sorter.directions

    items.sort do |left, right|
      compare(sorter.key_for(left), sorter.key_for(right), directions)
    end
  end

  # The comparison the Stimulus controller makes, in Ruby.
  def compare(left, right, directions)
    left.each_with_index do |value, index|
      other = right[index]
      next if value == other

      order = value < other ? -1 : 1
      return directions[index] == "desc" ? -order : order
    end

    0
  end

  test "with no sort, items keep the project's own order" do
    sorter = sorter_for([])
    items = project_items(item_node(number: 1), item_node(number: 2), item_node(number: 3))

    assert_equal [ "asc" ], sorter.directions
    assert_equal [ 1, 2, 3 ], sort(sorter, items.reverse).map(&:number)
  end

  test "a single-select sorts in the order the project lists its options" do
    sorter = sorter_for([ { direction: "ASC", field: { name: "Status" } } ])
    items = project_items(
      item_node(number: 1, values: { "Status" => "Done" }),
      item_node(number: 2, values: { "Status" => "Todo" }),
      item_node(number: 3)
    )

    # Todo before Done because that is the project's order, and the item with
    # no status after both.
    assert_equal [ 2, 1, 3 ], sort(sorter, items).map(&:number)
  end

  test "a descending sort reverses that comparison" do
    sorter = sorter_for([ { direction: "DESC", field: { name: "Status" } } ])
    items = project_items(
      item_node(number: 1, values: { "Status" => "Todo" }),
      item_node(number: 2, values: { "Status" => "Done" })
    )

    assert_equal %w[desc asc], sorter.directions
    assert_equal [ 2, 1 ], sort(sorter, items).map(&:number)
  end

  test "numbers compare as numbers rather than as text, negatives included" do
    sorter = sorter_for([ { direction: "ASC", field: { name: "Estimate" } } ])
    items = project_items(
      item_node(number: 1, values: { "Estimate" => 10 }),
      item_node(number: 2, values: { "Estimate" => 2 }),
      item_node(number: 3, values: { "Estimate" => -5 })
    )

    assert_equal [ 3, 2, 1 ], sort(sorter, items).map(&:number)
  end

  test "an iteration sorts by when the sprint starts, not by its title" do
    field = iteration_field(iterations: [
      iteration(title: "Zulu", start_date: "2025-01-01"),
      iteration(title: "Alpha", start_date: "2025-02-01")
    ])
    sorter = sorter_for([ { direction: "ASC", field: { name: "Sprint" } } ], fields: [ field ])
    items = project_items(
      item_node(number: 1, values: { "Sprint" => "Alpha" }),
      item_node(number: 2, values: { "Sprint" => "Zulu" })
    )

    assert_equal [ 2, 1 ], sort(sorter, items).map(&:number)
  end

  test "sorts by the columns every project has, not only its own fields" do
    sorter = sorter_for([ { direction: "ASC", field: { name: "Title" } } ])
    items = project_items(item_node(number: 1, title: "beta"), item_node(number: 2, title: "alpha"))

    assert_equal [ 2, 1 ], sort(sorter, items).map(&:number)
  end

  test "a sort entry GitHub could not name is dropped rather than breaking the view" do
    project = project(project_node(views: [ project_view(sort_by: [ { direction: "ASC", field: {} } ]) ]))

    assert_empty project.default_view.sort_by
  end

  test "sorts by the other columns every project has" do
    items = project_items(
      item_node(number: 1, repository: "rails/rails", labels: %w[ui], assignees: %w[zoe]),
      item_node(number: 2, repository: "basecamp/kamal", labels: %w[bug], assignees: %w[ann])
    )

    %w[Repository Labels Assignees].each do |name|
      sorter = sorter_for([ { direction: "ASC", field: { name: name } } ])

      assert_equal [ 2, 1 ], sort(sorter, items).map(&:number), "sorting by #{name}"
    end
  end

  test "an item in no iteration sorts after every sprint" do
    field = iteration_field(iterations: [ iteration(title: "S1", start_date: "2025-01-01") ])
    sorter = sorter_for([ { direction: "ASC", field: { name: "Sprint" } } ], fields: [ field ])
    items = project_items(
      item_node(number: 1),
      item_node(number: 2, values: { "Sprint" => "S1" })
    )

    assert_equal [ 2, 1 ], sort(sorter, items).map(&:number)
  end

  test "a view sorting by a field that has since been deleted still sorts" do
    sorter = sorter_for([ { direction: "ASC", field: { name: "Ghost" } } ])
    items = project_items(item_node(number: 1), item_node(number: 2))

    assert_equal [ 1, 2 ], sort(sorter, items).map(&:number)
  end

  test "a project with no saved views at all keeps its own order" do
    parsed = project(project_node(views: []))
    sorter = Projects::Sorter.new(project: parsed, view: parsed.default_view)

    assert_equal [ "asc" ], sorter.directions
  end
end
