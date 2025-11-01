# frozen_string_literal: true

# Represents users who can be assigned to issues in a repository
# Fetched from GitHub's GraphQL assignableUsers query
# Used for fast local search in Author and Assignee filter dropdowns
class RepositoryAssignableUser < ApplicationRecord
  belongs_to :repository

  validates :login, presence: true, uniqueness: { scope: :repository_id }

  # Search by login (case-insensitive)
  scope :search, ->(query) { where("login LIKE ?", "%#{sanitize_sql_like(query)}%") if query.present? }

  # Sort by login alphabetically
  scope :ordered, -> { order(login: :asc) }
end
