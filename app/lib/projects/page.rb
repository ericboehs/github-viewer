# frozen_string_literal: true

module Projects
  # One hundred items of a project, plus where to ask for the next hundred.
  #
  # `ProjectV2.items` takes no filter, so a filtered board is the whole board
  # fetched and then narrowed here. Pages are handed to the browser one at a
  # time - see Projects::Chunk and the project_board Stimulus controller -
  # rather than the request blocking until the last cursor comes back.
  class Page < Data.define(:items, :end_cursor, :has_next_page, :total_count)
    EMPTY = new(items: [], end_cursor: nil, has_next_page: false, total_count: 0)

    def self.from_graphql(connection, offset: 0)
      page_info = connection[:pageInfo] || {}
      nodes = Array(connection[:nodes])

      new(
        items: nodes.each_with_index.filter_map { |node, index| ItemBuilder.call(node, position: offset + index) },
        end_cursor: page_info[:endCursor],
        has_next_page: !!page_info[:hasNextPage],
        total_count: connection[:totalCount].to_i
      )
    end
  end
end
