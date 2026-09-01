# frozen_string_literal: true

# A single commit row in a pull request's Commits tab.
class CommitListItemComponent < ViewComponent::Base
  attr_reader :commit, :repository

  def initialize(commit:, repository:)
    @commit = commit
    @repository = repository
    super()
  end

  def sha
    commit[:sha].to_s
  end

  def short_sha
    sha.first(7)
  end

  def subject
    # `I18n.t` rather than the component's own `t`, so callers can read the
    # subject without first pushing the component through the render pipeline.
    commit[:subject].presence || I18n.t("pulls.commits.no_message")
  end

  def body
    commit[:body].presence
  end

  # Prefer the GitHub account, fall back to the name in the git metadata.
  # Commits authored from an email address that is not linked to an account
  # have the latter and not the former.
  def author_label
    commit[:author_login].presence || commit[:author_name].presence
  end

  def avatar_url
    commit[:author_avatar_url]
  end

  def authored_at
    commit[:authored_at]
  end

  def commit_url
    "https://#{repository.github_domain}/#{repository.owner}/#{repository.name}/commit/#{sha}"
  end
end
