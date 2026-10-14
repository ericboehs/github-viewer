# frozen_string_literal: true

# Drawing one project field value, wherever it appears.
#
# A board card and a table row show the same values in the same way: a
# single-select as a coloured chip, a number without the trailing `.0` GraphQL
# gives it, a date as a date, anything else as itself.
module ProjectFieldValues
  extend ActiveSupport::Concern

  private

  # The value as text, or nil when the item has none - which is different from
  # an empty string, and is why callers test this rather than the string.
  #
  # :reek:FeatureEnvy - Formats the value it is handed
  # :reek:NilCheck - A value that is absent is not a value that is empty
  # :reek:UtilityFunction - Formatting helper with no state of its own
  def field_text(value)
    return if value.nil? || value == ""
    return format("%g", value) if value.is_a?(Numeric)

    value.to_s
  end

  # Field values arrive from GraphQL, so a date is the string GitHub sent.
  # :reek:UtilityFunction - Formatting helper with no state of its own
  def field_chip_classes(field, value)
    option = field&.option(value)

    "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium #{option&.css_class || Projects::Option::DEFAULT_CLASS}"
  end
end
