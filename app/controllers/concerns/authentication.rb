# Provides session-based authentication behavior for controllers
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session
    end

    def require_authentication
      resume_session || attempt_development_auto_login || request_authentication
    end

    # Development convenience: sign in automatically instead of showing the
    # form. Hard-gated to the development environment *and* a loopback
    # request, so it can never apply to a deployed instance.
    #
    # Set DEV_AUTO_LOGIN=0 to exercise the real sign-in flow, or
    # DEV_AUTO_LOGIN_EMAIL to pick a user other than the seeded one.
    def attempt_development_auto_login
      return false unless development_auto_login?

      user = development_auto_login_user
      return false unless user

      Rails.logger.info "Auto-signing in #{user.email_address} (development)"
      start_new_session_for(user)
    end

    def development_auto_login?
      Rails.env.development? &&
        request.local? &&
        ENV["DEV_AUTO_LOGIN"] != "0" &&
        !session[:suppress_auto_login]
    end

    # :reek:UtilityFunction - Reads configuration, not request state
    def development_auto_login_user
      email = ENV["DEV_AUTO_LOGIN_EMAIL"]

      email ? User.find_by(email_address: email) : User.first
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    def find_session_by_cookie
      session_id = cookies.signed[:session_id]
      Session.find_by(id: session_id) if session_id
    end

    def request_authentication
      session[:return_to_after_authenticating] = request.url if storable_location?
      redirect_to new_session_path
    end

    # Only remember somewhere the user could actually look at.
    #
    # Background `fetch` calls keep running on an open page after a session
    # expires. Without this guard, whichever JSON endpoint happened to fire
    # last wins, and the next successful sign-in lands the user on a raw JSON
    # blob instead of the page they were on.
    def storable_location?
      request.get? && request.format.html? && !request.xhr?
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || root_url
    end

    def start_new_session_for(user)
      session.delete(:suppress_auto_login)

      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        Current.session = session
        cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax }
      end
    end

    def terminate_session
      Current.session.destroy
      cookies.delete(:session_id)
      # Otherwise development auto-login would sign the user straight back in
      # and make signing out look broken. Cleared on the next manual sign-in.
      session[:suppress_auto_login] = true
    end
end
