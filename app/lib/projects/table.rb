# frozen_string_literal: true

module Projects
  # Which columns a table view shows, in order.
  #
  # A saved view lists its own visible fields. A project opened without one -
  # or a view whose fields GitHub did not return - falls back to the project's
  # own fields, which is the same list GitHub's default table shows. Title
  # leads either way, because a row with no title is not a row.
  module Table
    TITLE = "Title"

    # Enough columns to be useful, few enough to stay on a screen.
    MAX_COLUMNS = 8

    module_function

    def columns(project:, view: nil)
      names = view&.field_names.presence || project.fields.map(&:name)

      ([ TITLE ] + names).uniq.first(MAX_COLUMNS)
    end
  end
end
