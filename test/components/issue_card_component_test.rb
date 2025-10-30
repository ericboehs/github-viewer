# frozen_string_literal: true

require "test_helper"

class IssueCardComponentTest < ViewComponent::TestCase
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
  end

  test "renders issue title as link" do
    issue = @repository.issues.create!(
      number: 42,
      title: "Fix critical bug",
      state: "open",
      author_login: "developer",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    render_inline(IssueCardComponent.new(issue: issue, repository: @repository))

    assert_selector "a[href*='/issues/42']", text: "Fix critical bug"
  end

  test "renders issue number" do
    issue = @repository.issues.create!(
      number: 123,
      title: "Test Issue",
      state: "open",
      author_login: "author",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    render_inline(IssueCardComponent.new(issue: issue, repository: @repository))

    assert_text "#123"
  end

  test "renders issue state badge" do
    issue = @repository.issues.create!(
      number: 1,
      title: "Test Issue",
      state: "open",
      author_login: "author",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    render_inline(IssueCardComponent.new(issue: issue, repository: @repository))

    assert_selector "svg"
  end

  test "renders author information" do
    issue = @repository.issues.create!(
      number: 1,
      title: "Test Issue",
      state: "open",
      author_login: "cooldev",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    render_inline(IssueCardComponent.new(issue: issue, repository: @repository))

    assert_text "opened by"
    assert_text "cooldev"
  end

  test "does not render author section when author_login is nil" do
    issue = @repository.issues.create!(
      number: 1,
      title: "Test Issue",
      state: "open",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    render_inline(IssueCardComponent.new(issue: issue, repository: @repository))

    assert_no_text "opened by"
  end

  test "renders labels when present" do
    issue = @repository.issues.create!(
      number: 1,
      title: "Test Issue",
      state: "open",
      author_login: "author",
      labels: [
        { "name" => "bug", "color" => "d73a4a" },
        { "name" => "enhancement", "color" => "a2eeef" }
      ],
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    render_inline(IssueCardComponent.new(issue: issue, repository: @repository))

    assert_text "bug"
    assert_text "enhancement"
  end

  test "does not render labels section when labels are empty" do
    issue = @repository.issues.create!(
      number: 1,
      title: "Test Issue",
      state: "open",
      author_login: "author",
      labels: [],
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    render_inline(IssueCardComponent.new(issue: issue, repository: @repository))

    # Verify labels section is not rendered by checking for wrapper div
    page = Nokogiri::HTML(rendered_content)
    label_wrapper = page.at_css(".flex.flex-wrap.gap-1.mt-2")
    assert_nil label_wrapper, "Labels wrapper should not be rendered when labels are empty"
  end

  test "renders comment count when greater than zero" do
    issue = @repository.issues.create!(
      number: 1,
      title: "Test Issue",
      state: "open",
      author_login: "author",
      comments_count: 5,
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    render_inline(IssueCardComponent.new(issue: issue, repository: @repository))

    assert_text "5"
    assert_selector "svg" # comment icon
  end

  test "does not render comment count when zero" do
    issue = @repository.issues.create!(
      number: 1,
      title: "Test Issue",
      state: "open",
      author_login: "author",
      comments_count: 0,
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    render_inline(IssueCardComponent.new(issue: issue, repository: @repository))

    # Should not show "0" comments
    assert_selector "svg", count: 1 # Only the state icon
  end

  test "renders time tag with Stimulus controller" do
    issue = @repository.issues.create!(
      number: 1,
      title: "Test Issue",
      state: "open",
      author_login: "author",
      github_created_at: 1.day.ago,
      github_updated_at: 2.hours.ago
    )

    render_inline(IssueCardComponent.new(issue: issue, repository: @repository))

    assert_selector "time[data-controller='time']"
    assert_selector "time[datetime]"
    assert_text "updated"
  end

  test "renders time tag with ISO 8601 datetime" do
    updated_at = Time.zone.parse("2025-01-15 14:30:45")
    issue = @repository.issues.create!(
      number: 1,
      title: "Test Issue",
      state: "open",
      author_login: "author",
      github_created_at: 1.day.ago,
      github_updated_at: updated_at
    )

    render_inline(IssueCardComponent.new(issue: issue, repository: @repository))

    assert_selector "time[datetime*='2025-01-15T']"
  end

  test "does not render timestamp when github_updated_at is nil" do
    issue = @repository.issues.build(
      number: 1,
      title: "Test Issue",
      state: "open",
      author_login: "author",
      github_created_at: 1.day.ago
    )
    issue.save!(validate: false)

    render_inline(IssueCardComponent.new(issue: issue, repository: @repository))

    assert_no_selector "time"
  end
end
