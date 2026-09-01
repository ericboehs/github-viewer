# frozen_string_literal: true

# Controller for viewing GitHub issues from tracked repositories
# List behaviour lives in IssueListable, which is shared with PullsController
class IssuesController < ApplicationController
  include IssueListable
  include IssueShowable

  def show
    load_and_display_issue
  end
end
