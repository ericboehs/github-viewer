# frozen_string_literal: true

require "test_helper"

# Tests Projects::Filter, which applies GitHub's project filter syntax in Ruby
# because `ProjectV2.items` has no filter argument of its own.
class Projects::FilterTest < ActiveSupport::TestCase
  include ProjectPayloads

  setup do
    @project = project(project_node(fields: [ single_select_field, number_field, sprint_field ]))
  end

  def sprint_field
    iteration_field(iterations: [ iteration(title: "Sprint 9", start_date: Date.current.to_s) ],
                    completed: [ iteration(title: "Sprint 8", start_date: (Date.current - 14).to_s) ])
  end

  def filter(query)
    Projects::Filter.new(query, project: @project)
  end

  def items(*nodes)
    project_items(*nodes)
  end

  test "an empty filter keeps everything" do
    assert filter(nil).empty?
    assert filter("   ").empty?
    assert_equal 2, filter("").apply(items(item_node(number: 1), item_node(number: 2))).size
  end

  test "matches a project field by name, case-insensitively" do
    todo = item_node(number: 1, values: { "Status" => "Todo" })
    done = item_node(number: 2, values: { "Status" => "Done" })

    assert_equal [ 1 ], filter("status:todo").apply(items(todo, done)).map(&:number)
  end

  test "commas within one qualifier are an or" do
    todo = item_node(number: 1, values: { "Status" => "Todo" })
    done = item_node(number: 2, values: { "Status" => "Done" })

    assert_equal [ 1, 2 ], filter("status:Todo,Done").apply(items(todo, done)).map(&:number)
  end

  test "a leading dash negates" do
    todo = item_node(number: 1, values: { "Status" => "Todo" })
    done = item_node(number: 2, values: { "Status" => "Done" })

    assert_equal [ 2 ], filter("-status:Todo").apply(items(todo, done)).map(&:number)
  end

  test "quoting keeps a value with a space in it whole" do
    node = item_node(number: 1, values: { "Status" => "In Progress" })

    assert_equal [ 1 ], filter('status:"In Progress"').apply(items(node)).map(&:number)
  end

  test "repeated qualifiers are anded" do
    both = item_node(number: 1, labels: %w[bug ui])
    one = item_node(number: 2, labels: %w[bug])

    assert_equal [ 1 ], filter("label:bug label:ui").apply(items(both, one)).map(&:number)
  end

  test "separates issues from pull requests and open from closed" do
    issue = item_node(number: 1)
    pull = item_node(number: 2, typename: "PullRequest")
    closed = item_node(number: 3, state: "CLOSED")

    all = items(issue, pull, closed)

    assert_equal [ 1, 3 ], filter("is:issue").apply(all).map(&:number)
    assert_equal [ 2 ], filter("is:pr").apply(all).map(&:number)
    assert_equal [ 1, 2 ], filter("is:open").apply(all).map(&:number)
    assert_equal [ 3 ], filter("is:closed").apply(all).map(&:number)
    assert_empty filter("is:nonsense").apply(all)
  end

  test "recognises merged and draft pull requests" do
    merged = item_node(number: 1, typename: "PullRequest", state: "MERGED", merged: true)
    draft = item_node(number: 2, typename: "PullRequest", draft: true)

    all = items(merged, draft)

    assert_equal [ 1 ], filter("is:merged").apply(all).map(&:number)
    assert_equal [ 2 ], filter("is:draft").apply(all).map(&:number)
  end

  test "@me is the account the token belongs to" do
    mine = item_node(number: 1, assignees: %w[octocat])
    theirs = item_node(number: 2, assignees: %w[someone])

    assert_equal [ 1 ], filter("assignee:@me").apply(items(mine, theirs)).map(&:number)
  end

  test "@current is the iteration containing today" do
    current = item_node(number: 1, values: { "Sprint" => "Sprint 9" })
    previous = item_node(number: 2, values: { "Sprint" => "Sprint 8" })

    assert_equal [ 1 ], filter("sprint:@current").apply(items(current, previous)).map(&:number)
  end

  test "no: finds items with nothing in a field or list" do
    empty = item_node(number: 1)
    filled = item_node(number: 2, values: { "Status" => "Todo" }, labels: %w[bug], assignees: %w[octocat])

    all = items(empty, filled)

    assert_equal [ 1 ], filter("no:status").apply(all).map(&:number)
    assert_equal [ 1 ], filter("no:label").apply(all).map(&:number)
    assert_equal [ 1 ], filter("no:assignee").apply(all).map(&:number)
  end

  test "matches an author and a repository, by full name or short" do
    node = item_node(number: 1, repository: "rails/rails")

    assert_equal [ 1 ], filter("repo:rails/rails").apply(items(node)).map(&:number)
    assert_equal [ 1 ], filter("repo:rails").apply(items(node)).map(&:number)
    assert_equal [ 1 ], filter("author:octocat").apply(items(node)).map(&:number)
  end

  test "a number field matches however GraphQL spelled the number" do
    node = item_node(number: 1, values: { "Estimate" => 3.0 })

    assert_equal [ 1 ], filter("estimate:3").apply(items(node)).map(&:number)
  end

  test "anything without a colon searches the title" do
    hit = item_node(number: 1, title: "Fix the login form")
    miss = item_node(number: 2, title: "Update the README")

    assert_equal [ 1 ], filter("login").apply(items(hit, miss)).map(&:number)
    assert_equal [ 2 ], filter("-login").apply(items(hit, miss)).map(&:number)
  end

  test "a dashed spelling names a field with a space in it" do
    project = project(project_node(fields: [ single_select_field(name: "Sub status", options: [ "Blocked" ]) ]))
    node = item_node(number: 1, values: { "Sub status" => "Blocked" })

    assert_equal [ 1 ], Projects::Filter.new("sub-status:Blocked", project: project).apply(items(node)).map(&:number)
  end

  test "reports a qualifier that names no field at all" do
    unknown = filter("nonsense:1 status:Todo")

    assert_equal [ "nonsense" ], unknown.unknown_keys
    assert_empty unknown.apply(items(item_node(number: 1, values: { "Status" => "Todo" })))
  end

  test "an empty quoted token is not a search for anything" do
    assert filter('""').empty?
  end

  test "an item with no author at all matches no author qualifier" do
    node = item_node(number: 1)
    node[:content][:author] = nil

    assert_empty filter("author:octocat").apply(items(node))
  end

  test "no: against a field the project does not have finds everything" do
    assert_equal [ 1 ], filter("no:nonsense").apply(items(item_node(number: 1))).map(&:number)
  end

  test "@current against a field that is not an iteration is just a value" do
    node = item_node(number: 1, values: { "Status" => "@current" })

    assert_equal [ 1 ], filter("status:@current").apply(items(node)).map(&:number)
  end

  test "@current matches nothing when no iteration is running" do
    project = project(project_node(fields: [ iteration_field(iterations: [], completed: []) ]))
    node = item_node(number: 1, values: { "Sprint" => "Sprint 1" })

    assert_empty Projects::Filter.new("sprint:@current", project: project).apply(items(node))
  end
end
