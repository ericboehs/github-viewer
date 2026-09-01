# frozen_string_literal: true

# Represents a GitHub personal access token for a specific domain
class GithubToken < ApplicationRecord
  belongs_to :user

  encrypts :token

  validates :domain, presence: true
  validates :token, presence: true
  validates :domain, uniqueness: { scope: :user_id }

  # The stored token, or nil when it cannot be decrypted.
  #
  # Ciphertext written under a different set of encryption keys is
  # unrecoverable. That must not take down the page that lets you replace it,
  # so treat an unreadable token as absent rather than letting the error escape.
  def readable_token
    token
  rescue ActiveRecord::Encryption::Errors::Decryption
    nil
  end

  def readable?
    readable_token.present?
  end

  # A preview safe to show in the UI, or nil when the token cannot be read.
  # :reek:FeatureEnvy - Formatting the decrypted string is the whole job
  def masked_token
    value = readable_token
    return nil if value.blank?

    "#{value.first(6)}*****#{value.last(2)}"
  end
end
