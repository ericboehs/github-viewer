# Handles the main dashboard view for authenticated users
class DashboardController < ApplicationController
  def index
    # Get recently updated repositories (last 10)
    @recently_updated_repos = Current.user.repositories
                                      .where.not(cached_at: nil)
                                      .order(cached_at: :desc)
                                      .limit(10)
  end
end
