# frozen_string_literal: true

# A project table: the view's visible fields as columns, one row per item.
#
# Everything that is not a board is drawn this way, a roadmap included. A
# roadmap's rows are the same rows, so a table is a truthful rendering of it
# rather than an empty page.
class ProjectTableComponent < ViewComponent::Base
  # The single bucket the Stimulus controller appends later rows into. A table
  # has no grouping, so it is a board with one column as far as that code is
  # concerned.
  ROWS = "rows"

  # See ProjectBoardComponent: a table's rows arrive the same way a board's
  # cards do, so it says the same thing while they are on their way.
  # :reek:BooleanParameter - Whether more items are coming is a yes or a no
  def initialize(layout:, items:, loading: false)
    @layout = layout
    @items = items
    @loading = loading
  end

  private

  attr_reader :layout, :items, :loading

  def columns
    layout.columns
  end
end
