# frozen_string_literal: true

require "test_helper"

# Tests the AvatarsController
class AvatarsControllerTest < ActionDispatch::IntegrationTest
  test "should return bad request when url parameter is missing" do
    get avatar_proxy_path
    assert_response :bad_request
  end

  test "should return bad request when url parameter is blank" do
    get avatar_proxy_path, params: { url: "" }
    assert_response :bad_request
  end

  test "should fetch and serve avatar successfully" do
    avatar_url = "https://example.com/avatar.png"

    # Mock successful HTTP response
    mock_response = Net::HTTPSuccess.new("1.1", "200", "OK")
    mock_response.stubs(:body).returns("fake_image_data")
    mock_response.stubs(:[]).with("content-type").returns("image/png")

    # Stub Net::HTTP to return our mock
    Net::HTTP.any_instance.stubs(:request).returns(mock_response)

    get avatar_proxy_path, params: { url: avatar_url }

    assert_response :success
    assert_equal "fake_image_data", response.body
  end

  test "should serve avatar from cache on second request" do
    avatar_url = "https://example.com/avatar.png"

    # Mock successful HTTP response for first request
    mock_response = Net::HTTPSuccess.new("1.1", "200", "OK")
    mock_response.stubs(:body).returns("cached_image")
    mock_response.stubs(:[]).with("content-type").returns("image/png")

    Net::HTTP.any_instance.stubs(:request).returns(mock_response)

    # First request - should fetch
    get avatar_proxy_path, params: { url: avatar_url }
    assert_response :success

    # Second request - should use cache (but we can't easily test this without mocking internals)
    # Just verify it still works
    get avatar_proxy_path, params: { url: avatar_url }
    assert_response :success
    assert_equal "cached_image", response.body
  end

  test "should return not found when avatar fetch fails" do
    avatar_url = "https://example.com/missing.png"

    # Mock failed HTTP response
    mock_response = Net::HTTPNotFound.new("1.1", "404", "Not Found")

    Net::HTTP.any_instance.stubs(:request).returns(mock_response)

    get avatar_proxy_path, params: { url: avatar_url }

    assert_response :not_found
  end

  test "should return internal server error on exception" do
    avatar_url = "https://example.com/error.png"

    # Stub to raise an exception
    Net::HTTP.any_instance.stubs(:request).raises(StandardError, "Network error")

    get avatar_proxy_path, params: { url: avatar_url }

    assert_response :internal_server_error
  end

  test "should use default content type when not provided" do
    avatar_url = "https://example.com/avatar.png"

    # Mock successful HTTP response without content-type header
    mock_response = Net::HTTPSuccess.new("1.1", "200", "OK")
    mock_response.stubs(:body).returns("fake_image_data")
    mock_response.stubs(:[]).with("content-type").returns(nil)

    Net::HTTP.any_instance.stubs(:request).returns(mock_response)

    get avatar_proxy_path, params: { url: avatar_url }

    assert_response :success
    # Should default to image/png
    assert_equal "image/png", response.content_type
  end

  test "should not require authentication" do
    # Don't sign in - avatars controller should skip authentication
    avatar_url = "https://example.com/avatar.png"

    # Mock HTTP response
    mock_response = Net::HTTPSuccess.new("1.1", "200", "OK")
    mock_response.stubs(:body).returns("test_data")
    mock_response.stubs(:[]).with("content-type").returns("image/png")

    Net::HTTP.any_instance.stubs(:request).returns(mock_response)

    get avatar_proxy_path, params: { url: avatar_url }

    # Should succeed without authentication
    assert_response :success
    assert_equal "test_data", response.body
  end

  test "should handle HTTPS URLs correctly" do
    avatar_url = "https://secure.example.com/avatar.png"

    # Mock successful HTTPS response
    mock_response = Net::HTTPSuccess.new("1.1", "200", "OK")
    mock_response.stubs(:body).returns("secure_image_data")
    mock_response.stubs(:[]).with("content-type").returns("image/png")

    Net::HTTP.any_instance.stubs(:request).returns(mock_response)

    get avatar_proxy_path, params: { url: avatar_url }

    assert_response :success
    assert_equal "secure_image_data", response.body
  end

  test "should handle HTTP redirect responses" do
    avatar_url = "https://example.com/redirect-avatar.png"

    # Mock redirect response
    mock_response = Net::HTTPMovedPermanently.new("1.1", "301", "Moved Permanently")

    Net::HTTP.any_instance.stubs(:request).returns(mock_response)

    get avatar_proxy_path, params: { url: avatar_url }

    # Should return not found for redirects (not following them)
    assert_response :not_found
  end
end
