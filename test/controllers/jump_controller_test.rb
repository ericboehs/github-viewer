# frozen_string_literal: true

require "test_helper"

# Tests the navbar's "go to" box: what a pasted GitHub URL turns into.
class JumpControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "jump@example.com", password: "password123")
    sign_in_as(@user)
  end

  test "sends a github.com URL to the same page here" do
    get jump_path(to: "https://github.com/rails/rails/pull/1")

    assert_redirected_to "/rails/rails/pull/1"
  end

  test "keeps the host for a GitHub Enterprise URL" do
    get jump_path(to: "https://va.ghe.com/software/eert/issues/2")

    assert_redirected_to "/va.ghe.com/software/eert/issues/2"
  end

  test "accepts a URL with no scheme" do
    get jump_path(to: "github.com/rails/rails/tree/main/app")

    assert_redirected_to "/rails/rails/tree/main/app"
  end

  test "accepts owner/repo on its own" do
    get jump_path(to: "rails/rails")

    assert_redirected_to "/rails/rails"
  end

  # GitHub renders this shorthand as a link to an issue, so it is worth
  # accepting from the clipboard too.
  test "accepts the owner/repo#number shorthand" do
    get jump_path(to: "rails/rails#123")

    assert_redirected_to "/rails/rails/issues/123"
  end

  test "drops query strings, fragments and a .git suffix" do
    get jump_path(to: "https://github.com/rails/rails.git")
    assert_redirected_to "/rails/rails"

    get jump_path(to: "https://github.com/rails/rails/issues/5?foo=bar#issuecomment-1")
    assert_redirected_to "/rails/rails/issues/5"
  end

  # GitHub has pages this application does not. Landing on the repository is
  # more use than landing on a 404.
  test "falls back to the repository for a page we do not serve" do
    get jump_path(to: "https://github.com/rails/rails/actions/runs/123")

    assert_redirected_to "/rails/rails"
  end

  test "falls back to the repository for an enterprise page we do not serve" do
    get jump_path(to: "https://va.ghe.com/software/eert/wiki/Home")

    assert_redirected_to "/va.ghe.com/software/eert"
  end

  test "sends back anything that is not repository-shaped" do
    get root_path
    get jump_path(to: "nonsense")

    assert_redirected_to root_path
    assert_match(/does not look like/i, flash[:alert])
  end

  test "sends back an empty query" do
    get jump_path(to: "")

    assert_redirected_to root_path
  end

  test "requires authentication" do
    delete session_path

    get jump_path(to: "rails/rails")

    assert_redirected_to new_session_path
  end
end
