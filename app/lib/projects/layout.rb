# frozen_string_literal: true

module Projects
  # Everything the rendering of one project view needs, decided once.
  #
  # A project page renders the same view three times over: the first page of
  # items with the page, and then each later page into a frame of its own. All
  # three need the same grouping, the same sort and the same columns, so they
  # are worked out once here and handed round rather than rebuilt per request
  # from the view.
  Layout = Data.define(:project, :view, :board, :sorter, :columns) do
    def self.for(project:, view: nil)
      new(
        project: project,
        view: view,
        board: Board.new(project: project, view: view),
        sorter: Sorter.new(project: project, view: view),
        columns: Table.columns(project: project, view: view)
      )
    end

    # A project with no saved views at all - which GitHub does not really
    # allow, but a stripped-down GraphQL response can produce - is a board.
    #
    # :reek:NilCheck - No view is itself an answer about the layout
    def board?
      view.nil? || view.board?
    end

    def group(items)
      board.group(items)
    end

    def key_for(item)
      sorter.key_for(item)
    end

    def directions
      sorter.directions
    end

    def group_field_name
      board.field_name
    end
  end
end
