# frozen_string_literal: true

module Projects
  # One entry of a view's sort: a field name and a direction.
  class Sort < Data.define(:field_name, :direction)
    DESCENDING = "DESC"

    def self.from_graphql(node)
      name = node.dig(:field, :name)
      return if name.blank?

      new(field_name: name, direction: node[:direction].to_s.upcase)
    end

    def descending?
      direction == DESCENDING
    end
  end
end
