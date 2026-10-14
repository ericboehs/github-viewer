# frozen_string_literal: true

module Projects
  # One choice of a single-select project field: "Todo", "In Progress", "Done".
  #
  # GitHub names the colour rather than giving one, from a fixed palette, and
  # uses it for the chip on a card and for the dot beside a board column's
  # name. `CLASSES` is that palette translated into the Tailwind pairs the rest
  # of this application draws chips with.
  class Option < Data.define(:id, :name, :color)
    CLASSES = {
      "GRAY" => "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200",
      "BLUE" => "bg-blue-100 text-blue-800 dark:bg-blue-900/40 dark:text-blue-200",
      "GREEN" => "bg-green-100 text-green-800 dark:bg-green-900/40 dark:text-green-200",
      "YELLOW" => "bg-yellow-100 text-yellow-800 dark:bg-yellow-900/40 dark:text-yellow-200",
      "ORANGE" => "bg-orange-100 text-orange-800 dark:bg-orange-900/40 dark:text-orange-200",
      "RED" => "bg-red-100 text-red-800 dark:bg-red-900/40 dark:text-red-200",
      "PINK" => "bg-pink-100 text-pink-800 dark:bg-pink-900/40 dark:text-pink-200",
      "PURPLE" => "bg-purple-100 text-purple-800 dark:bg-purple-900/40 dark:text-purple-200"
    }.freeze

    DEFAULT_CLASS = CLASSES.fetch("GRAY")

    def self.from_graphql(node)
      new(id: node[:id], name: node[:name].to_s, color: node[:color].to_s.upcase)
    end

    def css_class
      CLASSES.fetch(color, DEFAULT_CLASS)
    end
  end
end
