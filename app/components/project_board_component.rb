# frozen_string_literal: true

# A project board: one column per value of the field the view groups by.
#
# Only the first page of items is rendered here. The rest arrive later and are
# placed into these columns by the project_board Stimulus controller, which is
# why every column carries a `data-cards-for` handle and why there is a
# template for the columns that could not be known in advance - see
# Projects::Board.
class ProjectBoardComponent < ViewComponent::Base
  COLUMN_CLASSES = "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium"

  # How many cards a column shows before it offers to show the rest.
  #
  # A board's columns are rarely of a size with each other - a year of Done
  # against a handful of In Progress - and without a cap the page is as long as
  # the longest column, with everything below the board pushed out of reach.
  # The count in the column's header is still the true one.
  #
  # The Stimulus controller applies the same limit to the cards that arrive
  # after the page, which is why it is written into the markup as `data-limit`
  # rather than kept here alone.
  VISIBLE_LIMIT = 20

  # `loading` is whether more pages are still on their way, which every column
  # has to admit to: nothing here knows which of them the next page will fill.
  # :reek:BooleanParameter - Whether more items are coming is a yes or a no
  def initialize(layout:, items:, loading: false)
    @layout = layout
    @items = items
    @loading = loading
  end

  private

  attr_reader :layout, :items, :loading

  def groups
    layout.group(items)
  end
end
