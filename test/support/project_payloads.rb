# frozen_string_literal: true

# GraphQL payloads for the project pages, in the shape Github::ApiClient hands
# to the Projects objects.
#
# Projects V2 answers are deeply nested unions, and spelling one out inline
# buries whatever a test is actually about, so the shapes live here and each
# test overrides the one part it cares about.
module ProjectPayloads
  AVATAR = "https://avatars.githubusercontent.com/u/1?v=4"

  def single_select_field(name: "Status", options: %w[Todo Done])
    {
      id: "field-#{name.parameterize}",
      name: name,
      dataType: "SINGLE_SELECT",
      options: options.each_with_index.map { |option, index| { id: "opt-#{index}", name: option, color: "GREEN" } }
    }
  end

  def iteration_field(name: "Sprint", iterations: [], completed: [])
    {
      id: "field-sprint",
      name: name,
      dataType: "ITERATION",
      configuration: { iterations: iterations, completedIterations: completed }
    }
  end

  def iteration(title:, start_date: Date.current.to_s, duration: 14)
    { id: "it-#{title.parameterize}", title: title, startDate: start_date, duration: duration }
  end

  def number_field(name: "Estimate")
    { id: "field-estimate", name: name, dataType: "NUMBER" }
  end

  # :reek:LongParameterList - A view is a layout, a filter, a grouping and a sort
  def project_view(number: 1, name: "Board", layout: "BOARD_LAYOUT", filter: "", group_by: "Status",
                  sort_by: [], fields: [ "Title", "Status" ])
    {
      id: "view-#{number}",
      number: number,
      name: name,
      layout: layout,
      filter: filter,
      groupByFields: { nodes: (group_by ? [ { name: group_by } ] : []) },
      sortByFields: { nodes: sort_by },
      fields: { nodes: fields.map { |field| { name: field } } }
    }
  end

  # :reek:LongParameterList - Mirrors the GraphQL node this stands in for
  def project_node(number: 1, title: "Roadmap", fields: nil, views: nil, owner: "rails",
                  owner_type: "Organization", item_count: 3)
    {
      id: "PVT_1",
      number: number,
      title: title,
      shortDescription: "What we are doing",
      url: "https://github.com/orgs/#{owner}/projects/#{number}",
      closed: false,
      public: true,
      updatedAt: "2025-01-02T03:04:05Z",
      owner: { __typename: owner_type, login: owner },
      items: { totalCount: item_count },
      fields: { nodes: fields || [ single_select_field ] },
      views: { nodes: views || [ project_view ] }
    }
  end

  def project(node = project_node, domain: "github.com", viewer: "octocat")
    Projects::Project.from_graphql(node, github_domain: domain, viewer_login: viewer)
  end

  # :reek:LongParameterList - An item is the sum of its content and its fields
  # :reek:BooleanParameter - Mirrors the GraphQL booleans
  def item_node(number: 1, title: "Ship it", typename: "Issue", state: "OPEN", repository: "rails/rails",
                labels: [], assignees: [], values: {}, archived: false, merged: false, draft: false)
    {
      id: "PVTI_#{number}",
      isArchived: archived,
      fieldValues: { nodes: values.map { |name, value| field_value_node(name, value) } },
      content: content_node(
        number: number, title: title, typename: typename, state: state, repository: repository,
        labels: labels, assignees: assignees, merged: merged, draft: draft
      )
    }
  end

  # :reek:LongParameterList - Mirrors the GraphQL node this stands in for
  # :reek:BooleanParameter - Mirrors the GraphQL booleans
  def content_node(number:, title:, typename:, state:, repository:, labels:, assignees:, merged:, draft:)
    return { __typename: typename, title: title, creator: { login: "octocat", avatarUrl: AVATAR } } if typename == "DraftIssue"

    {
      __typename: typename,
      number: number,
      title: title,
      url: "https://github.com/#{repository}/#{typename == 'PullRequest' ? 'pull' : 'issues'}/#{number}",
      state: state,
      merged: merged,
      isDraft: draft,
      repository: { nameWithOwner: repository },
      author: { login: "octocat", avatarUrl: AVATAR },
      assignees: { nodes: assignees.map { |login| { login: login, avatarUrl: AVATAR } } },
      labels: { nodes: labels.map { |label| { name: label, color: "ff0000" } } }
    }
  end

  # The value union spells each type's value under its own key.
  def field_value_node(name, value)
    typename, key = case value
    when Numeric then [ "ProjectV2ItemFieldNumberValue", :number ]
    when Date then [ "ProjectV2ItemFieldDateValue", :date ]
    else [ "ProjectV2ItemFieldSingleSelectValue", :name ]
    end

    { __typename: typename, key => (value.is_a?(Date) ? value.to_s : value), field: { name: name } }
  end

  def items_page(nodes, has_next: false, cursor: nil, total: nil)
    Projects::Page.from_graphql(
      {
        totalCount: total || nodes.size,
        pageInfo: { hasNextPage: has_next, endCursor: cursor },
        nodes: nodes
      }
    )
  end

  def project_items(*nodes)
    items_page(nodes).items
  end
end
