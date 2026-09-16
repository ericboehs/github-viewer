# frozen_string_literal: true

# One card of a project board.
#
# A card can stand for an issue, a pull request, or a draft issue that exists
# only on the board and therefore has no number, no repository and nowhere to
# link to.
#
# `data-sort-key` is what lets the browser put a card in the right place: items
# arrive a page at a time into a board that is already on screen, so each card
# carries the key the saved view's sort would have given it. See
# Projects::Sorter and the project_board Stimulus controller.
class ProjectCardComponent < ViewComponent::Base
  include ProjectFieldValues

  # How many field values fit under a title before the card is more chips than
  # card.
  MAX_CHIPS = 4

  # How many faces fit in the corner of a card.
  MAX_AVATARS = 3

  def initialize(item:, layout:)
    @item = item
    @layout = layout
  end

  private

  attr_reader :item, :layout

  def sort_key
    layout.key_for(item).to_json
  end

  # Project items link to issues and pull requests on GitHub; this application
  # serves the same pages at the same paths, so the GitHub URL is turned back
  # into a local one. A draft issue has no URL at all.
  def path
    url = item.url

    GithubLink.path_for(url) if url.present?
  end

  def subtitle
    return if item.draft_issue?

    "#{item.repository} ##{item.number}"
  end

  # The field the board is grouped by is already the column heading, so
  # repeating it on every card in that column says nothing.
  #
  # :reek:TooManyStatements - Filters, formats and caps in one pass
  def chips
    grouped = layout.group_field_name
    project = layout.project

    item.fields.filter_map do |name, value|
      next if name == grouped

      text = field_text(value)
      [ name, text, project.field(name) ] if text
    end.first(MAX_CHIPS)
  end

  def assignees
    item.assignees.first(MAX_AVATARS)
  end
end
