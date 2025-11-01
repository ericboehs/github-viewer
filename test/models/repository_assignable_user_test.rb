require "test_helper"

class RepositoryAssignableUserTest < ActiveSupport::TestCase
  test "belongs to repository" do
    user = User.create!(email_address: "test@example.com", password: "password123")
    repository = Repository.create!(
      user: user,
      owner: "octocat",
      name: "hello-world",
      full_name: "octocat/hello-world",
      github_domain: "github.com"
    )

    assignable_user = RepositoryAssignableUser.create!(
      repository: repository,
      login: "octocat"
    )

    assert_equal repository, assignable_user.repository
  end

  test "validates presence of login" do
    user = User.create!(email_address: "test@example.com", password: "password123")
    repository = Repository.create!(
      user: user,
      owner: "octocat",
      name: "hello-world",
      full_name: "octocat/hello-world",
      github_domain: "github.com"
    )

    assignable_user = RepositoryAssignableUser.new(repository: repository)
    assert_not assignable_user.valid?
    assert_includes assignable_user.errors[:login], "can't be blank"
  end

  test "validates uniqueness of login scoped to repository" do
    user = User.create!(email_address: "test@example.com", password: "password123")
    repository = Repository.create!(
      user: user,
      owner: "octocat",
      name: "hello-world",
      full_name: "octocat/hello-world",
      github_domain: "github.com"
    )

    RepositoryAssignableUser.create!(
      repository: repository,
      login: "octocat"
    )

    duplicate = RepositoryAssignableUser.new(
      repository: repository,
      login: "octocat"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:login], "has already been taken"
  end

  test "search scope filters by login" do
    user = User.create!(email_address: "test@example.com", password: "password123")
    repository = Repository.create!(
      user: user,
      owner: "octocat",
      name: "hello-world",
      full_name: "octocat/hello-world",
      github_domain: "github.com"
    )

    RepositoryAssignableUser.create!(repository: repository, login: "octocat")
    RepositoryAssignableUser.create!(repository: repository, login: "johndoe")
    RepositoryAssignableUser.create!(repository: repository, login: "janedoe")

    results = repository.repository_assignable_users.search("doe")
    assert_equal 2, results.count
    assert_includes results.map(&:login), "johndoe"
    assert_includes results.map(&:login), "janedoe"
  end

  test "search scope returns all when query is nil" do
    user = User.create!(email_address: "test@example.com", password: "password123")
    repository = Repository.create!(
      user: user,
      owner: "octocat",
      name: "hello-world",
      full_name: "octocat/hello-world",
      github_domain: "github.com"
    )

    RepositoryAssignableUser.create!(repository: repository, login: "alice")
    RepositoryAssignableUser.create!(repository: repository, login: "bob")

    results = repository.repository_assignable_users.search(nil)
    assert_equal 2, results.count
  end

  test "search scope returns all when query is empty string" do
    user = User.create!(email_address: "test@example.com", password: "password123")
    repository = Repository.create!(
      user: user,
      owner: "octocat",
      name: "hello-world",
      full_name: "octocat/hello-world",
      github_domain: "github.com"
    )

    RepositoryAssignableUser.create!(repository: repository, login: "alice")
    RepositoryAssignableUser.create!(repository: repository, login: "bob")

    results = repository.repository_assignable_users.search("")
    assert_equal 2, results.count
  end

  test "ordered scope sorts by login alphabetically" do
    user = User.create!(email_address: "test@example.com", password: "password123")
    repository = Repository.create!(
      user: user,
      owner: "octocat",
      name: "hello-world",
      full_name: "octocat/hello-world",
      github_domain: "github.com"
    )

    RepositoryAssignableUser.create!(repository: repository, login: "charlie")
    RepositoryAssignableUser.create!(repository: repository, login: "alice")
    RepositoryAssignableUser.create!(repository: repository, login: "bob")

    ordered = repository.repository_assignable_users.ordered
    assert_equal [ "alice", "bob", "charlie" ], ordered.map(&:login)
  end
end
