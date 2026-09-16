# frozen_string_literal: true

module Projects
  # The columns of a board, and which one an item belongs in.
  #
  # A board groups by one field. When that field enumerates its own values -
  # a single-select, an iteration - every column is known before a single item
  # arrives, including the empty ones, which is what lets the page draw the
  # board once and fill it in as pages of items come back. Grouping by anything
  # else (Repository, Assignees, a text field) has no such list, so those
  # columns are discovered from the items themselves and created in the browser
  # as they first appear.
  #
  # The last column is always the one for items with no value for the field,
  # which GitHub labels "No Status" and puts at the end.
  class Board
    # `key` is what the markup and the Stimulus controller address a column by,
    # so it has to survive being put in an id.
    Column = Data.define(:key, :name, :css_class)

    # The field a board falls back to when its view names none, which is the
    # field GitHub creates every project with.
    DEFAULT_GROUP = "Status"

    NO_VALUE = "__none__"
    UNGROUPED = "__all__"

    attr_reader :project, :field

    def initialize(project:, view: nil)
      @project = project
      @field = project.field(view&.grouping) || project.field(DEFAULT_GROUP)
    end

    def field_name
      field&.name
    end

    # True when the columns below are all the columns there will ever be, and
    # the browser will not have to invent any.
    def enumerated?
      !!field&.enumerated?
    end

    # Drawn up front: the field's own values, then the empty bucket. Grouping
    # by a field with no enumerable values gives only that bucket, and the rest
    # are discovered.
    def columns
      return [ ungrouped_column ] unless field

      (enumerated? ? field.values : []).map { |value| column_for(value) } << none_column
    end

    # :reek:FeatureEnvy - Reads the item to decide which column it lands in
    def column_of(item)
      return ungrouped_column unless field

      value = item.field_value(field.name)

      value.blank? ? none_column : column_for(value)
    end

    # Items keyed by the column they belong to: the columns known in advance
    # first, in the project's order, then any discovered among these items.
    def group(items)
      buckets = items.group_by { |item| column_of(item) }

      columns.map { |column| [ column, buckets.delete(column) || [] ] } + buckets.to_a
    end

    private

    def column_for(value)
      option = field.option(value)
      name = value.to_s

      Column.new(key: name.parameterize.presence || NO_VALUE, name: name,
                css_class: option&.css_class || Option::DEFAULT_CLASS)
    end

    def none_column
      Column.new(key: NO_VALUE, name: I18n.t("projects.board.no_value", field: field_name),
                css_class: Option::DEFAULT_CLASS)
    end

    # :reek:UtilityFunction - A column with nothing of the board in it is still the board's
    def ungrouped_column
      Column.new(key: UNGROUPED, name: I18n.t("projects.board.all_items"), css_class: Option::DEFAULT_CLASS)
    end
  end
end
