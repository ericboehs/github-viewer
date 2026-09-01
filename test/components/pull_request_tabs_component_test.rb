# frozen_string_literal: true

require "test_helper"

# Tests PullRequestTabsComponent, the Conversation/Commits/Files sub-navigation
class PullRequestTabsComponentTest < ViewComponent::TestCase
  # Route helpers are what the component builds its hrefs from, and the test
  # asserts on those hrefs rather than restating the URL shapes.
  include Rails.application.routes.url_helpers

  setup do
    @user = User.create!(email_address: "tabs@example.com", password: "password123")
    @repository = @user.repositories.create!(
      github_domain: "github.com",
      owner: "rails",
      name: "rails",
      full_name: "rails/rails",
      url: "https://github.com/rails/rails"
    )
    @pull = @repository.issues.create!(
      number: 7,
      title: "A pull request",
      state: "open",
      pull_request: true,
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )
  end

  test "renders all three tabs linking to their pages" do
    render_inline(build_component)

    assert_text I18n.t("pulls.tabs.conversation")
    assert_text I18n.t("pulls.tabs.commits")
    assert_text I18n.t("pulls.tabs.files")

    assert_selector "a[href='#{repository_pull_path(@repository, 7)}']"
    assert_selector "a[href='#{commits_repository_pull_path(@repository, 7)}']"
    assert_selector "a[href='#{files_repository_pull_path(@repository, 7)}']"
  end

  test "marks only the current tab as active" do
    render_inline(build_component(current_tab: :files))

    assert_selector "a[aria-current='page']", count: 1
    assert_selector "a[href='#{files_repository_pull_path(@repository, 7)}'][aria-current='page']"
  end

  test "shows cached counts as badges" do
    @pull.update!(comments_count: 4, commits_count: 12, changed_files_count: 3)

    render_inline(build_component)

    assert_text "4"
    assert_text "12"
    assert_text "3"
  end

  test "omits badges for counts that have never been synced" do
    @pull.update!(comments_count: 0, commits_count: nil, changed_files_count: nil)

    render_inline(build_component)

    assert_selector "nav a span.rounded-full", count: 1, text: "0"
  end

  test "renders the diffstat when additions or deletions are known" do
    @pull.update!(additions: 1608, deletions: 42)

    render_inline(build_component)

    assert_text "+1,608"
    assert_text "42"
  end

  test "hides the diffstat entirely when neither side is known" do
    refute build_component.diffstat?

    render_inline(build_component)

    assert_no_text "+0"
  end

  test "treats a known count on one side and nothing on the other as zero" do
    @pull.update!(deletions: 3)

    component = build_component

    assert component.diffstat?
    assert_equal 0, component.additions
    assert_equal 3, component.deletions
  end

  private

  def build_component(current_tab: :conversation)
    PullRequestTabsComponent.new(issue: @pull, repository: @repository, current_tab: current_tab)
  end
end
