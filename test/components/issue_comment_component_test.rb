# frozen_string_literal: true

require "test_helper"

class IssueCommentComponentTest < ViewComponent::TestCase
  setup do
    @user = User.create!(
      email_address: "test@example.com",
      password: "password123",
      github_token: "test_token",
      github_domain: "github.com"
    )
    @repository = @user.repositories.create!(
      owner: "testuser",
      name: "testrepo",
      full_name: "testuser/testrepo",
      url: "https://github.com/testuser/testrepo",
      github_domain: "github.com"
    )
    @issue = @repository.issues.create!(
      number: 1,
      title: "Test Issue",
      state: "open",
      author_login: "author",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )
  end

  test "renders comment with author avatar" do
    comment = @issue.issue_comments.create!(
      github_id: 123456,
      author_login: "commenter",
      author_avatar_url: "https://avatars.githubusercontent.com/u/123",
      body: "Test comment",
      github_created_at: 2.hours.ago,
      github_updated_at: 2.hours.ago
    )

    render_inline(IssueCommentComponent.new(comment: comment))

    assert_selector "img[alt='commenter']"
  end

  test "renders comment without avatar when none provided" do
    comment = @issue.issue_comments.create!(
      github_id: 123457,
      author_login: "commenter",
      body: "Test comment",
      github_created_at: 2.hours.ago,
      github_updated_at: 2.hours.ago
    )

    render_inline(IssueCommentComponent.new(comment: comment))

    assert_no_selector "img"
    assert_text "commenter"
  end

  test "renders comment author name" do
    comment = @issue.issue_comments.create!(
      github_id: 123458,
      author_login: "commenter",
      body: "Test comment",
      github_created_at: 2.hours.ago,
      github_updated_at: 2.hours.ago
    )

    render_inline(IssueCommentComponent.new(comment: comment))

    assert_text "commenter"
  end

  test "renders comment body with markdown" do
    comment = @issue.issue_comments.create!(
      github_id: 123459,
      author_login: "commenter",
      body: "# Test Heading\n\nTest **bold** text",
      github_created_at: 2.hours.ago,
      github_updated_at: 2.hours.ago
    )

    render_inline(IssueCommentComponent.new(comment: comment))

    assert_selector ".markdown"
    assert_text "Test Heading"
    assert_text "Test bold text"
  end

  test "renders time tag with Stimulus controller" do
    comment = @issue.issue_comments.create!(
      github_id: 123460,
      author_login: "commenter",
      body: "Test comment",
      github_created_at: 2.hours.ago,
      github_updated_at: 2.hours.ago
    )

    render_inline(IssueCommentComponent.new(comment: comment))

    assert_selector "time[data-controller='time']"
    assert_selector "time[datetime]"
  end

  test "renders time tag with ISO 8601 datetime" do
    created_at = Time.zone.parse("2025-01-15 14:30:45")
    comment = @issue.issue_comments.create!(
      github_id: 123461,
      author_login: "commenter",
      body: "Test comment",
      github_created_at: created_at,
      github_updated_at: created_at
    )

    render_inline(IssueCommentComponent.new(comment: comment))

    assert_selector "time[datetime*='2025-01-15T']"
  end

  test "renders unknown author when author login is nil" do
    comment = @issue.issue_comments.create!(
      github_id: 123462,
      body: "Test comment",
      github_created_at: 2.hours.ago,
      github_updated_at: 2.hours.ago
    )

    render_inline(IssueCommentComponent.new(comment: comment))

    assert_text "Unknown"
  end

  test "does not render timestamp when github_created_at is nil" do
    comment = @issue.issue_comments.build(
      github_id: 123463,
      author_login: "commenter",
      body: "Test comment"
    )
    comment.save!(validate: false)

    render_inline(IssueCommentComponent.new(comment: comment))

    assert_no_selector "time"
  end
end
