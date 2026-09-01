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
      resume_session || request_authentication
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
      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        Current.session = session
        cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax }
      end
    end

    def terminate_session
      Current.session.destroy
      cookies.delete(:session_id)
    end
end
