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

    assert_text "cooldev opened"
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

  test "renders comment count when issue has comments" do
    issue = @repository.issues.create!(
      number: 1,
      title: "Test Issue",
      state: "open",
      author_login: "author",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    # Create some issue_comments
    3.times do |i|
      issue.issue_comments.create!(
        github_id: i + 1,
        body: "Test comment",
        author_login: "commenter",
        author_avatar_url: "https://example.com/avatar.png",
        github_created_at: 1.hour.ago,
        github_updated_at: 1.hour.ago
      )
    end

    render_inline(IssueCardComponent.new(issue: issue, repository: @repository))

    # Comment count should be displayed with icon and number
    assert_selector "svg"
    assert_text "3"
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
    assert_text "Updated"
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

  test "does not render updated timestamp when github_updated_at is nil" do
    issue = @repository.issues.build(
      number: 1,
      title: "Test Issue",
      state: "open",
      author_login: "author",
      github_created_at: 1.day.ago
    )
    issue.save!(validate: false)

    render_inline(IssueCardComponent.new(issue: issue, repository: @repository))

    # Should still show created time, but not updated time
    assert_selector "time", count: 1
    assert_no_text "Updated"
  end

  test "author link works when query only contains author filter" do
    issue = @repository.issues.build(
      number: 1,
      title: "Test Issue",
      state: "open",
      author_login: "testuser",
      github_created_at: 1.day.ago,
      github_updated_at: 1.day.ago
    )
    issue.save!(validate: false)

    # Simulate query that only contains author:someoneelse
    with_request_url "/repositories/#{@repository.id}/issues?q=author:someoneelse" do
      render_inline(IssueCardComponent.new(issue: issue, repository: @repository))

      # Link should replace the author filter with just author:testuser
      assert_selector "a[href*='author%3Atestuser']"
    end
  end

  test "author link works when no query parameter is present" do
    issue = @repository.issues.create!(
      number: 1,
      title: "Test Issue",
      state: "open",
      author_login: "testuser",
      github_created_at: 1.day.ago,
      github_updated_at: 1.day.ago
    )

    # Simulate no query parameter at all
    with_request_url "/repositories/#{@repository.id}/issues" do
      render_inline(IssueCardComponent.new(issue: issue, repository: @repository))

      # Should show author link
      assert_selector "a", text: "testuser"
      # Link should just contain author:testuser (not prepended with anything)
      assert_selector "a[href*='q=author%3Atestuser']"
      # Verify the query doesn't have extra content before the author filter
      link = page.find("a", text: "testuser")
      refute_includes link[:href], "%20author%3A"  # No space before author:
    end
  end
end
