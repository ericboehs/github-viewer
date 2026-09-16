# frozen_string_literal: true

# A later page of a project's items, on its way into a board or table that is
# already on screen.
#
# `ProjectV2.items` has no filter argument, so the whole project has to be read
# before a filtered view of it is complete. Rather than hold the request open
# for a project with thousands of items, the first page renders with the page
# and the rest follow in chained frames - see ProjectsController#items.
#
# The items are rendered hidden, tagged with the column they belong to, and
# moved into place by the project_board Stimulus controller. Hidden rather than
# in a `<template>` because a template's contents are not in the document, and
# so cannot be found by Stimulus, by a test, or by anything else.
class ProjectChunkComponent < ViewComponent::Base
  def initialize(layout:, items:, complete:)
    @layout = layout
    @items = items
    @complete = complete
  end

  # A page whose items were all filtered out still has to announce that it was
  # the last one, so an empty chunk is only skipped mid-stream.
  def render?
    @items.any? || @complete
  end

  private

  attr_reader :layout, :items, :complete

  # Only the columns these items actually landed in: an empty column has
  # nothing to append.
  def groups
    layout.group(items).reject { |_column, column_items| column_items.empty? }
  end
end
