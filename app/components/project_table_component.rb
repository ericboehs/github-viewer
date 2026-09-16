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

  def initialize(layout:, items:)
    @layout = layout
    @items = items
  end

  private

  attr_reader :layout, :items

  def columns
    layout.columns
  end
end
