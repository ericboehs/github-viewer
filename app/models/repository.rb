# Represents a GitHub repository tracked by a user
class Repository < ApplicationRecord
  belongs_to :user
  has_many :issues, dependent: :destroy

  validates :owner, presence: true
  validates :name, presence: true
  validates :full_name, presence: true
  validates :github_domain, presence: true
  validates :owner, uniqueness: { scope: [ :user_id, :github_domain, :name ] }

  scope :recently_cached, -> { where("cached_at > ?", 5.minutes.ago) }
  scope :stale, -> { where("cached_at IS NULL OR cached_at <= ?", 5.minutes.ago) }

  # :reek:NilCheck - cached_at requires explicit nil check for staleness
  def stale?
    cached_at.blank? || cached_at <= 5.minutes.ago
  end

  # :reek:NilCheck - cached_at requires explicit nil check for user message
  def staleness_in_words
    return "Never synced" unless cached_at

    "#{time_ago_in_words(cached_at)} ago"
  end

  private

  # :reek:UtilityFunction - Simple time formatting helper
  def time_ago_in_words(time)
    seconds = Time.current - time
    case seconds
    when 0..59 then "#{seconds.to_i} seconds"
    when 60..3599 then "#{(seconds / 60).to_i} minutes"
    when 3600..86_399 then "#{(seconds / 3600).to_i} hours"
    else "#{(seconds / 86_400).to_i} days"
    end
  end
end
