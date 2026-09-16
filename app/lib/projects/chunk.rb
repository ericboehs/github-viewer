# frozen_string_literal: true

module Projects
  # One page of a project's items, once the filter has been applied to it.
  #
  # Pages come back from GitHub a hundred at a time and are rendered into a
  # page that already exists, so each one has to carry the cursor for the next
  # and enough of a count to know when to stop.
  #
  # The cap is what stops a project with tens of thousands of items walking
  # every cursor on every page load. A board that hits it says so rather than
  # quietly showing part of itself.
  class Chunk < Data.define(:page, :items, :next_cursor, :next_offset, :total_count, :truncated)
    MAX_PAGES = Github::ApiConfiguration::MAX_PROJECT_ITEM_PAGES

    # Archived items are hidden from GitHub's own views, so they are dropped
    # before the filter ever sees them.
    #
    # :reek:LongParameterList - A chunk is a page plus where it sits and what narrowed it
    def self.build(result:, filter:, page: 1, offset: 0)
      fetched = result.items
      another = result.has_next_page
      more = another && page < MAX_PAGES

      new(
        page: page,
        items: filter.apply(fetched.reject(&:archived)),
        next_cursor: (result.end_cursor if more),
        next_offset: offset + fetched.size,
        total_count: result.total_count,
        truncated: another && !more
      )
    end

    # :reek:NilCheck - No cursor is what "there is no next page" is written as
    def complete?
      next_cursor.nil?
    end

    def next_page
      page + 1
    end
  end
end
