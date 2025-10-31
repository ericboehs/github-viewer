require "test_helper"

# Tests for Repository model validations, associations, and staleness tracking
class RepositoryTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @repository = repositories(:one)
  end

  test "should be valid with valid attributes" do
    repository = Repository.new(
      user: @user,
      owner: "octocat",
      name: "Hello-World",
      full_name: "octocat/Hello-World",
      url: "https://github.com/octocat/Hello-World"
    )
    assert repository.valid?
  end

  test "should require owner" do
    @repository.owner = nil
    assert_not @repository.valid?
    assert_includes @repository.errors[:owner], "can't be blank"
  end

  test "should require name" do
    @repository.name = nil
    assert_not @repository.valid?
    assert_includes @repository.errors[:name], "can't be blank"
  end

  test "should require full_name" do
    @repository.full_name = nil
    assert_not @repository.valid?
    assert_includes @repository.errors[:full_name], "can't be blank"
  end

  test "should belong to user" do
    assert_equal @user, @repository.user
  end

  test "should have many issues" do
    assert_respond_to @repository, :issues
  end

  test "should enforce unique owner/name per user" do
    duplicate = Repository.new(
      user: @user,
      owner: @repository.owner,
      name: @repository.name,
      full_name: "#{@repository.owner}/#{@repository.name}"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:owner], "has already been taken"
  end

  test "should allow same owner/name for different users" do
    other_user = users(:two)
    repository = Repository.new(
      user: other_user,
      owner: @repository.owner,
      name: @repository.name,
      full_name: @repository.full_name
    )
    assert repository.valid?
  end

  test "should return true for stale when cached_at is nil" do
    @repository.cached_at = nil
    assert @repository.stale?
  end

  test "should return true for stale when cached_at is old" do
    @repository.cached_at = 10.minutes.ago
    assert @repository.stale?
  end

  test "should return false for stale when cached_at is recent" do
    @repository.cached_at = 1.minute.ago
    assert_not @repository.stale?
  end

  test "should return recently cached repositories" do
    @repository.update!(cached_at: 1.minute.ago)
    assert_includes Repository.recently_cached, @repository
  end

  test "should return stale repositories" do
    @repository.update!(cached_at: 10.minutes.ago)
    assert_includes Repository.stale, @repository
  end

  test "should return staleness in words for never synced" do
    @repository.cached_at = nil
    assert_equal "Never synced", @repository.staleness_in_words
  end

  test "should return staleness in words for recent sync" do
    @repository.cached_at = 30.seconds.ago
    staleness = @repository.staleness_in_words
    assert_match(/\d+ seconds ago/, staleness)
  end

  test "should destroy dependent issues" do
    issue = @repository.issues.create!(
      number: 999,
      title: "Test Issue",
      state: "open"
    )
    issue_id = issue.id

    @repository.destroy

    assert_not Issue.exists?(issue_id)
  end

  test "should return staleness in words for minutes" do
    @repository.cached_at = 2.minutes.ago
    staleness = @repository.staleness_in_words
    assert_match(/\d+ minutes ago/, staleness)
  end

  test "should return staleness in words for hours" do
    @repository.cached_at = 2.hours.ago
    staleness = @repository.staleness_in_words
    assert_match(/\d+ hours ago/, staleness)
  end

  test "should return staleness in words for days" do
    @repository.cached_at = 2.days.ago
    staleness = @repository.staleness_in_words
    assert_match(/\d+ days ago/, staleness)
  end
end
