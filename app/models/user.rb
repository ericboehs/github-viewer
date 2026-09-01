# Represents an application user with email-based authentication
class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :repositories, dependent: :destroy
  has_many :github_tokens, dependent: :destroy

  normalizes :email_address, with: ->(email) { email.strip.downcase }

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, if: -> { new_record? || !password.nil? }

  # The usable token for a domain, or nil when none is stored or the stored one
  # cannot be decrypted. Callers already handle a missing token, so an
  # unreadable one degrades the same way instead of raising mid-request.
  def github_token_for(domain)
    token = github_tokens.find_by(domain: domain)
    token if token&.readable?
  end

  def avatar_url(size: 40)
    require "digest"
    hash = Digest::MD5.hexdigest(email_address.downcase)
    "https://www.gravatar.com/avatar/#{hash}?s=#{size}&d=404"
  end

  def initials
    email_prefix = email_address&.split("@")&.first
    email_prefix&.first&.upcase || "?"
  end

  def self.find_by_password_reset_token!(token)
    find_signed!(token, purpose: :password_reset)
  end
end
