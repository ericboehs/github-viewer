# frozen_string_literal: true

module Projects
  # A column of a project's data - "Status", "Sprint", "Estimate" - as the
  # project defines it, independently of any item's value for it.
  #
  # Two things need the definition rather than the values: a board, whose
  # columns are a single-select field's options in the project's order
  # (including the ones nothing is in yet), and the filter parser, which has to
  # know that `sprint:` names a field at all before it can decide that
  # `@current` means the iteration running today.
  class Field < Data.define(:id, :name, :data_type, :options, :iterations)
    # The types a board can be grouped by with the columns known in advance,
    # because the field enumerates its own values.
    ENUMERATED_TYPES = %w[SINGLE_SELECT ITERATION].freeze

    # :reek:TooManyStatements - Reads the two type-specific shapes out of one node
    def self.from_graphql(node)
      configuration = node[:configuration] || {}
      iterations = Array(configuration[:iterations]).map { |it| Iteration.from_graphql(it) } +
                  Array(configuration[:completedIterations]).map { |it| Iteration.from_graphql(it, completed: true) }

      new(
        id: node[:id],
        name: node[:name].to_s,
        data_type: node[:dataType].to_s,
        options: Array(node[:options]).map { |option| Option.from_graphql(option) },
        iterations: iterations
      )
    end

    # What a filter qualifier has to say to name this field. GitHub matches
    # field names case-insensitively; the dashed spelling is what people type
    # instead of quoting a name with a space in it.
    def keys
      downcased = name.downcase

      [ downcased, downcased.tr(" ", "-") ].uniq
    end

    def single_select?
      data_type == "SINGLE_SELECT"
    end

    def iteration?
      data_type == "ITERATION"
    end

    # True when this field's values can be listed without looking at any item,
    # which is what lets a board draw an empty column.
    def enumerated?
      ENUMERATED_TYPES.include?(data_type)
    end

    # The field's own values, in the order the project keeps them, as the
    # board's columns.
    def values
      return options.map(&:name) if single_select?
      return iterations.reject(&:completed).map(&:title) if iteration?

      []
    end

    def option(value)
      options.find { |option| option.name.casecmp?(value.to_s) }
    end

    # `sprint:@current` - the iteration whose date range contains today.
    def current_iteration
      iterations.find(&:current?)
    end
  end
end
