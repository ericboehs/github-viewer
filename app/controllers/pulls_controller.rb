# frozen_string_literal: true

# Controller for viewing GitHub pull requests from tracked repositories
#
# GitHub models pull requests as issues, so this reuses the issue list/show
# machinery with the list scope forced to `:pulls` (an `is:pr` qualifier).
class PullsController < ApplicationController
  include IssueListable
  include IssueShowable

  def show
    load_and_display_issue
  end

  private

  def list_scope
    IssueScoped::PULLS_SCOPE
  end
end
