# frozen_string_literal: true

require "test_helper"

# Tests CommitListItemComponent, a single row in the Commits tab
class CommitListItemComponentTest < ViewComponent::TestCase
  setup do
    @user = User.create!(email_address: "commits@example.com", password: "password123")
    @repository = @user.repositories.create!(
      github_domain: "github.com",
      owner: "rails",
      name: "rails",
      full_name: "rails/rails",
      url: "https://github.com/rails/rails"
    )
  end

  test "renders the subject, author and abbreviated sha" do
    render_inline(build_component)

    assert_text "Fix the thing"
    assert_text "ericboehs"
    assert_selector "a", text: "abc1234"
  end

  test "links the sha to the commit on the repository's host" do
    component = build_component

    assert_equal "https://github.com/rails/rails/commit/abc1234def5678", component.commit_url
  end

  test "links to a GitHub Enterprise host for enterprise repositories" do
    @repository.update!(github_domain: "va.ghe.com")

    assert_match %r{\Ahttps://va\.ghe\.com/}, build_component.commit_url
  end

  # Git splits a message into a subject line and an optional body. Only the
  # subject belongs in the row heading.
  test "renders the commit body separately from the subject" do
    render_inline(build_component(body: "Explains why in more detail."))

    assert_text "Fix the thing"
    assert_text "Explains why in more detail."
  end

  test "omits the body when there is none" do
    assert_nil build_component(body: "").body
  end

  # Commits authored from an email address not linked to a GitHub account have
  # git metadata but no account, so the row falls back to the git name.
  test "falls back to the git author name when there is no GitHub account" do
    component = build_component(author_login: nil, author_avatar_url: nil)

    assert_equal "Eric Boehs", component.author_label

    render_inline(component)

    assert_text "Eric Boehs"
    assert_no_selector "img"
  end

  test "shows nothing rather than a blank byline when neither author is known" do
    component = build_component(author_login: nil, author_name: nil, author_avatar_url: nil)

    assert_nil component.author_label
  end

  test "substitutes a placeholder for an empty commit message" do
    assert_equal I18n.t("pulls.commits.no_message"), build_component(subject: "").subject
  end

  private

  def build_component(**overrides)
    commit = {
      sha: "abc1234def5678",
      subject: "Fix the thing",
      body: "",
      author_name: "Eric Boehs",
      author_login: "ericboehs",
      author_avatar_url: "https://example.com/avatar.png",
      authored_at: 2.days.ago
    }.merge(overrides)

    CommitListItemComponent.new(commit: commit, repository: @repository)
  end
end
