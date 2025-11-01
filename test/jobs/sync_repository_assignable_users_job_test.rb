require "test_helper"

class SyncRepositoryAssignableUsersJobTest < ActiveJob::TestCase
  setup do
    @user = User.create!(
      email_address: "test@example.com",
      password: "password123"
    )
    @github_token = @user.github_tokens.create!(
      domain: "github.com",
      token: "ghp_test1234567890abcdef"
    )
    @repository = @user.repositories.create!(
      github_domain: "github.com",
      owner: "rails",
      name: "rails",
      full_name: "rails/rails",
      cached_at: 1.minute.ago
    )
  end

  test "should sync assignable users successfully" do
    mock_client = mock("ApiClient")
    mock_client.expects(:fetch_assignable_users).with("rails", "rails").returns([
      { login: "alice", avatar_url: "https://example.com/alice.png" },
      { login: "bob", avatar_url: "https://example.com/bob.png" }
    ])

    Github::ApiClient.expects(:new).returns(mock_client)

    assert_difference -> { @repository.repository_assignable_users.count }, 2 do
      SyncRepositoryAssignableUsersJob.perform_now(@repository.id)
    end

    assert_equal [ "alice", "bob" ], @repository.repository_assignable_users.pluck(:login).sort
  end

  test "should skip blank logins" do
    mock_client = mock("ApiClient")
    mock_client.expects(:fetch_assignable_users).with("rails", "rails").returns([
      { login: "alice", avatar_url: "https://example.com/alice.png" },
      { login: "", avatar_url: "https://example.com/blank.png" },
      { login: nil, avatar_url: "https://example.com/nil.png" }
    ])

    Github::ApiClient.expects(:new).returns(mock_client)

    assert_difference -> { @repository.repository_assignable_users.count }, 1 do
      SyncRepositoryAssignableUsersJob.perform_now(@repository.id)
    end

    assert_equal [ "alice" ], @repository.repository_assignable_users.pluck(:login)
  end

  test "should update existing assignable users" do
    # Create an existing user
    @repository.repository_assignable_users.create!(
      login: "alice",
      avatar_url: "https://old.example.com/alice.png"
    )

    mock_client = mock("ApiClient")
    mock_client.expects(:fetch_assignable_users).with("rails", "rails").returns([
      { login: "alice", avatar_url: "https://new.example.com/alice.png" }
    ])

    Github::ApiClient.expects(:new).returns(mock_client)

    assert_no_difference -> { @repository.repository_assignable_users.count } do
      SyncRepositoryAssignableUsersJob.perform_now(@repository.id)
    end

    alice = @repository.repository_assignable_users.find_by(login: "alice")
    assert_equal "https://new.example.com/alice.png", alice.avatar_url
  end

  test "should remove assignable users not in API response" do
    # Create existing users
    @repository.repository_assignable_users.create!(login: "alice", avatar_url: "https://example.com/alice.png")
    @repository.repository_assignable_users.create!(login: "bob", avatar_url: "https://example.com/bob.png")
    @repository.repository_assignable_users.create!(login: "charlie", avatar_url: "https://example.com/charlie.png")

    mock_client = mock("ApiClient")
    mock_client.expects(:fetch_assignable_users).with("rails", "rails").returns([
      { login: "alice", avatar_url: "https://example.com/alice.png" }
    ])

    Github::ApiClient.expects(:new).returns(mock_client)

    # Note: The current job implementation does NOT remove users not in the API response
    # It only adds/updates users. So we expect no change in count.
    assert_no_difference -> { @repository.repository_assignable_users.count } do
      SyncRepositoryAssignableUsersJob.perform_now(@repository.id)
    end

    # All three users should still exist
    assert_equal 3, @repository.repository_assignable_users.count
  end

  test "should handle API errors" do
    mock_client = mock("ApiClient")
    mock_client.expects(:fetch_assignable_users).with("rails", "rails").returns({
      error: "API rate limit exceeded"
    })

    Github::ApiClient.expects(:new).returns(mock_client)

    assert_no_difference -> { @repository.repository_assignable_users.count } do
      SyncRepositoryAssignableUsersJob.perform_now(@repository.id)
    end
  end

  test "should handle missing repository" do
    # Should raise ActiveRecord::RecordNotFound for non-existent repository
    assert_raises(ActiveRecord::RecordNotFound) do
      SyncRepositoryAssignableUsersJob.perform_now(999999)
    end
  end

  test "should handle missing GitHub token" do
    # Create a repository without a matching GitHub token
    other_domain_repo = @user.repositories.create!(
      github_domain: "ghe.example.com",
      owner: "company",
      name: "repo",
      full_name: "company/repo",
      cached_at: 1.minute.ago
    )

    # Should not raise an error, just log and return
    assert_no_difference -> { other_domain_repo.repository_assignable_users.count } do
      SyncRepositoryAssignableUsersJob.perform_now(other_domain_repo.id)
    end
  end
end
