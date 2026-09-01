# Represents a GitHub issue or pull request cached from the GitHub API
# GitHub models pull requests as issues, so both are stored in this table and
# distinguished by the +pull_request+ flag.
class Issue < ApplicationRecord
  belongs_to :repository
  has_many :issue_comments, dependent: :destroy

  validates :number, presence: true, uniqueness: { scope: :repository_id }
  validates :title, presence: true
  validates :state, presence: true, inclusion: { in: %w[open closed] }

  scope :open, -> { where(state: "open") }
  scope :closed, -> { where(state: "closed") }
  scope :by_state, ->(state) { where(state: state) if state.present? }
  scope :with_label, ->(label) { where("labels LIKE ?", "%#{label}%") if label.present? }
  scope :assigned_to, ->(login) { where("assignees LIKE ?", "%#{login}%") if login.present? }
  scope :authored_by, ->(login) { where(author_login: login) if login.present? }
  scope :recently_cached, -> { where("cached_at > ?", 5.minutes.ago) }
  scope :issues_only, -> { where(pull_request: false) }
  scope :pull_requests_only, -> { where(pull_request: true) }
  scope :of_type, ->(type) { type.presence == "pr" ? pull_requests_only : issues_only if type.present? }

  def open?
    state == "open"
  end

  def closed?
    state == "closed"
  end

  def merged?
    merged_at.present?
  end

  def draft?
    pull_request? && self[:draft].present?
  end

  # Display state used by IssueStateComponent: open/closed/merged/draft
  def display_state
    return "merged" if merged?
    return "draft" if draft? && open?
    state
  end

  def label_names
    (labels || []).map { |label| label["name"] }
  end

  def assignee_logins
    (assignees || []).map { |assignee| assignee["login"] }
  end
end
