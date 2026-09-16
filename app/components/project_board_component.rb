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

  def initialize(layout:, items:)
    @layout = layout
    @items = items
  end

  private

  attr_reader :layout, :items

  def groups
    layout.group(items)
  end
end
