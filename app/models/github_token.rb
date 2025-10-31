# frozen_string_literal: true

# Represents a GitHub personal access token for a specific domain
class GithubToken < ApplicationRecord
  belongs_to :user

  encrypts :token

  validates :domain, presence: true
  validates :token, presence: true
  validates :domain, uniqueness: { scope: :user_id }
end
