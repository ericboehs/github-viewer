# frozen_string_literal: true

module Projects
  # One row of a project: an issue, a pull request, or a draft issue that only
  # exists on the board.
  #
  # The three are one type here because a project shows them in one list and
  # they differ only in what can be said about them - a draft has no number, no
  # repository and no state. `content_type` is what tells them apart, and the
  # nil-ness of the rest follows from it.
  #
  # `fields` is the item's values for the project's own fields, keyed by field
  # name, which is what the filter, the grouping and the chips on a card all
  # read.
  #
  # :reek:TooManyConstants - Content types and states are small closed sets
  class Item < Data.define(
    :id, :position, :content_type, :number, :title, :url, :state,
    :repository, :author, :assignees, :labels, :fields, :archived
  )
    ISSUE = "Issue"
    PULL_REQUEST = "PullRequest"
    DRAFT_ISSUE = "DraftIssue"

    OPEN = "open"
    CLOSED = "closed"
    MERGED = "merged"
    DRAFT = "draft"

    def issue?
      content_type == ISSUE
    end

    def pull_request?
      content_type == PULL_REQUEST
    end

    # An item typed straight into the board, with no issue behind it. It can
    # still carry field values, so it belongs in a column like anything else,
    # but there is nowhere to link it to.
    def draft_issue?
      content_type == DRAFT_ISSUE
    end

    def open?
      state == OPEN
    end

    def closed?
      state == CLOSED || state == MERGED
    end

    def merged?
      state == MERGED
    end

    def field_value(field_name)
      fields[field_name.to_s]
    end

    def label_names
      labels.map { |label| label[:name] }
    end

    def assignee_logins
      assignees.map { |assignee| assignee[:login] }
    end
  end
end
