# frozen_string_literal: true

module Projects
  # One sprint of an iteration field.
  #
  # An iteration has a start date and a length rather than an end date, so the
  # range has to be worked out, which is also what makes `@current` - the
  # filter GitHub writes as `sprint:@current` - answerable without asking the
  # API which iteration is running today.
  class Iteration < Data.define(:id, :title, :start_date, :duration, :completed)
    # :reek:BooleanParameter - Completed is which of the two lists GitHub sent this in
    def self.from_graphql(node, completed: false)
      start_date = node[:startDate]

      new(
        id: node[:id],
        title: node[:title].to_s,
        start_date: (Date.parse(start_date) if start_date.present?),
        duration: node[:duration].to_i,
        completed: completed
      )
    end

    # Exclusive of the day after the last, the way a duration in days reads.
    def range
      return unless start_date

      start_date...(start_date + duration)
    end

    # :reek:ControlParameter - Injectable today, so the caller can ask about another day
    def current?(today = Date.current)
      range&.cover?(today) || false
    end
  end
end
