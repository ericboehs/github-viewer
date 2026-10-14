# frozen_string_literal: true

module Projects
  # The sort a saved view asks for, expressed as a key per item.
  #
  # Items arrive one page of a hundred at a time and are placed into the board
  # as they arrive, so sorting cannot happen once at the end on the server: a
  # card has to know where it belongs relative to cards that have not been
  # fetched yet. Each card therefore carries its own key, and the browser
  # inserts it in order - see the project_board Stimulus controller.
  #
  # Keys are arrays compared element by element against `directions`, with the
  # item's position in the project as the final tiebreaker. A view with no sort
  # of its own is left in the project's own order, which is what that
  # tiebreaker already is.
  class Sorter
    ASCENDING = "asc"
    DESCENDING = "desc"

    # Wide enough for any project's item count and any GitHub estimate.
    NUMBER_WIDTH = 12

    # :reek:ControlParameter - A view with no sort of its own is the same as no view
    def initialize(project:, view:)
      @project = project
      @sorts = view&.sort_by || []
    end

    def key_for(item)
      @sorts.map { |sort| component(item, sort.field_name) } << pad(item.position)
    end

    # One entry per key component, so the browser knows which comparisons to
    # reverse.
    def directions
      @sorts.map { |sort| sort.descending? ? DESCENDING : ASCENDING } << ASCENDING
    end

    private

    # :reek:TooManyStatements - Picks a comparable form per field type
    def component(item, field_name)
      field = @project.field(field_name)
      value = field ? item.field_value(field.name) : built_in(item, field_name)

      return pad(option_index(field, value)) if field&.single_select?
      return iteration_key(field, value) if field&.iteration?
      return pad(value) if value.is_a?(Numeric)

      value.to_s.downcase
    end

    # A single-select sorts in the order the project lists its options, not
    # alphabetically: Todo comes before Done.
    # :reek:UtilityFunction - Ordering helper, at home beside the sort it serves
    def option_index(field, value)
      options = field.options
      index = options.index { |option| option.name.casecmp?(value.to_s) }

      # Items with no value sort after every option, as they do on GitHub.
      index || options.size
    end

    # Sprints sort by when they start, so the titles need not be orderable.
    # :reek:UtilityFunction - Ordering helper, at home beside the sort it serves
    def iteration_key(field, value)
      iteration = field.iterations.find { |candidate| candidate.title.casecmp?(value.to_s) }
      start_date = iteration&.start_date

      start_date ? start_date.iso8601 : "9999-99-99"
    end

    # The columns every project has, whatever fields were added to it.
    # :reek:UtilityFunction - Ordering helper, at home beside the sort it serves
    def built_in(item, field_name)
      case field_name.to_s.downcase
      when "title" then item.title
      when "repository" then item.repository
      when "assignees" then item.assignee_logins.sort.first
      when "labels" then item.label_names.sort.first
      end
    end

    # Numbers have to compare as strings, because that is what a DOM attribute
    # is, so they are padded to a fixed width. Negatives are rare in a project
    # field but would otherwise sort above everything.
    def pad(value)
      number = value.to_f
      return format("0%0#{NUMBER_WIDTH}.2f", number) unless number.negative?

      # The complement keeps -5 before -1 without a signed comparison.
      format("-%0#{NUMBER_WIDTH}.2f", 10**(NUMBER_WIDTH - 3) + number)
    end
  end
end
