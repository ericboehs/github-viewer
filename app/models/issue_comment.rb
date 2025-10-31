# Represents a comment on a GitHub issue cached from the GitHub API
class IssueComment < ApplicationRecord
  belongs_to :issue

  validates :github_id, presence: true, uniqueness: { scope: :issue_id }

  default_scope -> { order(github_created_at: :asc) }
end
