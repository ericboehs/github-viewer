# frozen_string_literal: true

# Controller for proxying and caching GitHub avatar images
# :reek:TooManyStatements - Controller actions orchestrate caching and proxying
class AvatarsController < ApplicationController
  skip_before_action :require_authentication

  # :reek:TooManyStatements - Show action orchestrates cache check and fetch
  def show
    avatar_url = params[:url]
    return head :bad_request if avatar_url.blank?

    # Cache avatars for 30 days
    cache_key = "avatar:#{Digest::SHA256.hexdigest(avatar_url)}"

    cached_data = Rails.cache.read(cache_key)

    if cached_data
      send_avatar(cached_data[:content_type], cached_data[:body])
    else
      fetch_and_cache_avatar(avatar_url, cache_key)
    end
  end

  private

  # :reek:TooManyStatements - Method orchestrates HTTP fetch, caching, and response
  def fetch_and_cache_avatar(avatar_url, cache_key)
    response = fetch_avatar(avatar_url)

    if response.is_a?(Net::HTTPSuccess)
      content_type = response["content-type"] || "image/png"
      body = response.body

      # Cache for 30 days
      Rails.cache.write(cache_key, { content_type: content_type, body: body }, expires_in: 30.days)

      send_avatar(content_type, body)
    else
      head :not_found
    end
  rescue StandardError => error
    Rails.logger.error("Failed to fetch avatar: #{error.message}")
    head :internal_server_error
  end

  # :reek:TooManyStatements - Method configures HTTP client and makes request
  # :reek:UtilityFunction - Instance method for potential future extension
  def fetch_avatar(avatar_url)
    uri = URI.parse(avatar_url)
    http = Net::HTTP.new(uri.host, uri.port)

    # Configure SSL for HTTPS requests
    if uri.scheme == "https"
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER

      # Create custom cert store without CRL checking
      # This still verifies the certificate chain but skips CRL checks
      # which often fail in corporate environments due to inaccessible CRL endpoints
      cert_store = OpenSSL::X509::Store.new
      cert_store.set_default_paths
      # Don't set V_FLAG_CRL_CHECK or V_FLAG_CRL_CHECK_ALL to skip CRL validation
      http.cert_store = cert_store
    end

    http.read_timeout = 5
    http.open_timeout = 5

    request = Net::HTTP::Get.new(uri.request_uri)
    http.request(request)
  end

  def send_avatar(content_type, body)
    send_data body,
              type: content_type,
              disposition: "inline",
              expires_in: 30.days
  end
end
