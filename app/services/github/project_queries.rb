# frozen_string_literal: true

module Github
  # The GraphQL documents behind the project pages.
  #
  # Projects V2 exists only in GraphQL - there is no REST equivalent - and the
  # documents are long enough that keeping them next to the client's methods
  # would bury them, so they live here.
  #
  # Two shapes are worth knowing when reading them:
  #
  # * `ProjectV2FieldConfiguration` is a union of the three field types, so
  #   anything asking for a field's name has to spread all three. A member that
  #   is not spread comes back as an empty object rather than an error, which
  #   is why the parsing side treats a nameless node as "a field type we do not
  #   read".
  # * `ProjectV2ItemFieldValue` is a union too, one member per field type, each
  #   putting its value under a different key.
  #
  # :reek:TooManyConstants - One constant per document and fragment
  module ProjectQueries
    # A field as the board and the filters need it: enough to know its type,
    # and for the two enumerated types, its values.
    FIELD_DEFINITION = <<~GRAPHQL
      fragment FieldDefinition on ProjectV2FieldConfiguration {
        ... on ProjectV2Field { id name dataType }
        ... on ProjectV2SingleSelectField {
          id
          name
          dataType
          options { id name color }
        }
        ... on ProjectV2IterationField {
          id
          name
          dataType
          configuration {
            iterations { id title startDate duration }
            completedIterations { id title startDate duration }
          }
        }
      }
    GRAPHQL

    # The same union, where only the name is wanted.
    FIELD_NAME = <<~GRAPHQL
      fragment FieldName on ProjectV2FieldConfiguration {
        ... on ProjectV2Field { id name dataType }
        ... on ProjectV2SingleSelectField { id name dataType }
        ... on ProjectV2IterationField { id name dataType }
      }
    GRAPHQL

    VIEW_FIELDS = <<~GRAPHQL
      fragment ViewFields on ProjectV2View {
        id
        number
        name
        layout
        filter
        groupByFields(first: 5) { nodes { ...FieldName } }
        sortByFields(first: 5) { nodes { direction field { ...FieldName } } }
        fields(first: 50) { nodes { ...FieldName } }
      }
    GRAPHQL

    # What a row of a project list needs, and no more.
    PROJECT_SUMMARY = <<~GRAPHQL
      fragment ProjectSummary on ProjectV2 {
        id
        number
        title
        shortDescription
        url
        closed
        public
        updatedAt
        owner {
          __typename
          ... on Organization { login }
          ... on User { login }
        }
        items { totalCount }
      }
    GRAPHQL

    PROJECT_DETAIL = <<~GRAPHQL
      fragment ProjectDetail on ProjectV2 {
        ...ProjectSummary
        fields(first: 50) { nodes { ...FieldDefinition } }
        views(first: 20) { nodes { ...ViewFields } }
      }
    GRAPHQL

    ITEM_FIELDS = <<~GRAPHQL
      fragment ItemFields on ProjectV2Item {
        id
        isArchived
        fieldValues(first: 30) {
          nodes {
            __typename
            ... on ProjectV2ItemFieldSingleSelectValue { name field { ...FieldName } }
            ... on ProjectV2ItemFieldTextValue { text field { ...FieldName } }
            ... on ProjectV2ItemFieldNumberValue { number field { ...FieldName } }
            ... on ProjectV2ItemFieldDateValue { date field { ...FieldName } }
            ... on ProjectV2ItemFieldIterationValue { title field { ...FieldName } }
          }
        }
        content {
          __typename
          ... on DraftIssue {
            title
            creator { login avatarUrl }
            assignees(first: 10) { nodes { login avatarUrl } }
          }
          ... on Issue {
            number
            title
            url
            state
            repository { nameWithOwner }
            author { login avatarUrl }
            assignees(first: 10) { nodes { login avatarUrl } }
            labels(first: 10) { nodes { name color } }
          }
          ... on PullRequest {
            number
            title
            url
            state
            isDraft
            merged
            repository { nameWithOwner }
            author { login avatarUrl }
            assignees(first: 10) { nodes { login avatarUrl } }
            labels(first: 10) { nodes { name color } }
          }
        }
      }
    GRAPHQL

    module_function

    # Every project of one organization or user.
    # :reek:ControlParameter - The root field is the only difference between the two
    def owner_projects(organization:)
      root = organization ? "organization" : "user"

      <<~GRAPHQL
        #{PROJECT_SUMMARY}
        query($login: String!, $first: Int!) {
          #{root}(login: $login) {
            projectsV2(first: $first, orderBy: { field: UPDATED_AT, direction: DESC }) {
              nodes { ...ProjectSummary }
            }
          }
        }
      GRAPHQL
    end

    # The projects a repository is linked to. They belong to the repository's
    # owner or to another organization entirely; the repository only points at
    # them.
    def repository_projects
      <<~GRAPHQL
        #{PROJECT_SUMMARY}
        query($owner: String!, $name: String!, $first: Int!) {
          repository(owner: $owner, name: $name) {
            projectsV2(first: $first, orderBy: { field: UPDATED_AT, direction: DESC }) {
              nodes { ...ProjectSummary }
            }
          }
        }
      GRAPHQL
    end

    # One project with its fields and saved views, plus the login the token
    # belongs to, which is what `assignee:@me` resolves to.
    # :reek:ControlParameter - The root field is the only difference between the two
    def project(organization:)
      root = organization ? "organization" : "user"

      <<~GRAPHQL
        #{PROJECT_SUMMARY}
        #{FIELD_DEFINITION}
        #{FIELD_NAME}
        #{VIEW_FIELDS}
        #{PROJECT_DETAIL}
        query($login: String!, $number: Int!) {
          viewer { login }
          #{root}(login: $login) {
            projectV2(number: $number) { ...ProjectDetail }
          }
        }
      GRAPHQL
    end

    # One page of items, addressed by the project's node id so that the same
    # document serves organization and user projects.
    def project_items
      <<~GRAPHQL
        #{FIELD_NAME}
        #{ITEM_FIELDS}
        query($id: ID!, $first: Int!, $after: String) {
          node(id: $id) {
            ... on ProjectV2 {
              items(first: $first, after: $after) {
                totalCount
                pageInfo { hasNextPage endCursor }
                nodes { ...ItemFields }
              }
            }
          }
        }
      GRAPHQL
    end
  end
end
