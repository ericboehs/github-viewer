# Represents a GitHub issue cached from the GitHub API
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
  scope :recently_cached, -> { where("cached_at > ?", 5.minutes.ago) }

  def open?
    state == "open"
  end

  def closed?
    state == "closed"
  end

  def label_names
    (labels || []).map { |label| label["name"] }
  end

  def assignee_logins
    (assignees || []).map { |assignee| assignee["login"] }
  end
end
