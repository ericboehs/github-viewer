# frozen_string_literal: true

module Projects
  # A saved view of a project: the tabs across the top of a GitHub project.
  #
  # A view is a layout, a filter and an ordering over the same set of items, so
  # it is what this application reads to decide whether to draw a board or a
  # table, which field makes the board's columns, and what to put in the filter
  # box before the user has typed anything.
  #
  # GitHub's `groupByFields` and `sortByFields` are connections rather than
  # single fields, and the older singular `groupBy` / `visibleFields` spellings
  # have been removed from the schema, so only the plural ones are asked for.
  # Only the first entry of each is used: nothing here renders nested groups.
  #
  # Grouping is spelled twice in the schema, and which one holds the answer
  # depends on the layout - see #grouping.
  class View < Data.define(:id, :number, :name, :layout, :filter, :group_by, :vertical_group_by, :sort_by, :field_names)
    BOARD = "BOARD_LAYOUT"
    TABLE = "TABLE_LAYOUT"

    # :reek:TooManyStatements - Unpacks four connections out of one node
    def self.from_graphql(node)
      new(
        id: node[:id],
        number: node[:number].to_i,
        name: node[:name].to_s,
        layout: node[:layout].to_s,
        filter: node[:filter].to_s,
        group_by: field_names(node[:groupByFields]).first,
        vertical_group_by: field_names(node[:verticalGroupByFields]).first,
        sort_by: Array(node.dig(:sortByFields, :nodes)).filter_map { |sort| Sort.from_graphql(sort) },
        field_names: field_names(node[:fields])
      )
    end

    # The field configuration union answers with an empty node for a field type
    # this query did not ask about, hence the compact.
    def self.field_names(connection)
      Array(connection&.dig(:nodes)).filter_map { |node| node[:name].presence }
    end

    def board?
      layout == BOARD
    end

    # Everything that is not a board is drawn as a table. A roadmap has no
    # renderer here, and its rows are the same rows, so a table is a truthful
    # answer rather than an empty page.
    def table?
      !board?
    end

    # The field this view is divided up by.
    #
    # A board's columns come from `verticalGroupByFields` and a table's row
    # grouping from `groupByFields`: two spellings in the schema for one idea
    # here. A board's own `groupByFields` holds its swimlanes instead, which
    # nothing here draws, so reading that one would leave every board grouped
    # by whatever Board falls back to.
    def grouping
      board? ? vertical_group_by : group_by
    end
  end
end
