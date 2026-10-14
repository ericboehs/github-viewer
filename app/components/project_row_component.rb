# frozen_string_literal: true

# One row of a project table.
#
# A table view lists the fields it shows, in order, and the first of them is
# almost always Title. Three of those names are not project fields at all but
# facets of the item itself, which is why they are read from the item rather
# than from its field values.
#
# :reek:TooManyConstants - Three column names and the readings of them
class ProjectRowComponent < ViewComponent::Base
  include ProjectFieldValues

  ASSIGNEES = "Assignees"
  LABELS = "Labels"
  REPOSITORY = "Repository"

  # The three column names a table can show that are not project fields at
  # all, and how to read each off the item instead.
  BUILT_IN = {
    ASSIGNEES => ->(item) { item.assignee_logins.join(", ") },
    LABELS => ->(item) { item.label_names.join(", ") },
    REPOSITORY => ->(item) { item.repository }
  }.freeze

  def initialize(item:, layout:)
    @item = item
    @layout = layout
  end

  private

  attr_reader :item, :layout

  def columns
    layout.columns
  end

  def sort_key
    layout.key_for(item).to_json
  end

  def path
    url = item.url

    GithubLink.path_for(url) if url.present?
  end

  # :reek:UtilityFunction - Column predicates, at home beside the rest of the row
  def title_column?(name)
    name == Projects::Table::TITLE
  end

  # :reek:UtilityFunction - Column predicates, at home beside the rest of the row
  def built_in?(name)
    BUILT_IN.key?(name)
  end

  def built_in_text(name)
    BUILT_IN.fetch(name).call(item)
  end

  def value_for(name)
    field_text(item.field_value(name))
  end

  def field_for(name)
    layout.project.field(name)
  end
end
