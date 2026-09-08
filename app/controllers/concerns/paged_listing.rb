# frozen_string_literal: true

# Paging for views that read straight from GitHub rather than from the cache.
#
# The REST endpoints behind them report no total, so there is no last page to
# link to and no count to show. The only question that can be answered is
# whether a further page exists, which a full page of results implies - which
# is why GitHub's own commit history offers Older and Newer and nothing else.
module PagedListing
  extend ActiveSupport::Concern

  PAGE_SIZE = 50

  private

  # Anything unparseable, negative or absent is the first page.
  def current_page
    page = params[:page].to_i
    page < 1 ? 1 : page
  end
end
