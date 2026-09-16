# frozen_string_literal: true

module Projects
  # Turns one `ProjectV2Item` node into a Projects::Item.
  #
  # An item is two things stitched together: the content it points at - an
  # issue, a pull request, or a draft that exists only on the board - and the
  # project's own field values for it. The content is a union, so which keys
  # are there depends on `__typename`; the field values are a union too, one
  # member per field type, each spelling its value under a different key.
  #
  # :reek:UtilityFunction - A builder: all input, no state
  module ItemBuilder
    # The value of a single-select, text, number, date or iteration field, by
    # the key its type puts it under. Anything else - the built-in Labels,
    # Assignees and Repository fields - is read off the content instead, so it
    # is left out rather than duplicated.
    VALUE_KEYS = {
      "ProjectV2ItemFieldSingleSelectValue" => :name,
      "ProjectV2ItemFieldTextValue" => :text,
      "ProjectV2ItemFieldNumberValue" => :number,
      "ProjectV2ItemFieldDateValue" => :date,
      "ProjectV2ItemFieldIterationValue" => :title
    }.freeze

    # The project's Title field repeats the item's own title, so it is not a
    # chip worth drawing.
    IGNORED_FIELDS = [ "Title" ].freeze

    module_function

    # Returns nil for an item whose content has been deleted, which GitHub
    # keeps in the project as a node with no content at all.
    #
    # :reek:TooManyStatements - Assembles one flat record from two nested shapes
    def call(node, position:)
      content = node[:content]
      return if content.blank?

      typename = content[:__typename].to_s

      Item.new(
        id: node[:id],
        position: position,
        content_type: typename,
        number: content[:number],
        title: content[:title].to_s,
        url: content[:url],
        state: state_for(typename, content),
        repository: content.dig(:repository, :nameWithOwner),
        author: person(content[:author] || content[:creator]),
        assignees: people(content[:assignees]),
        labels: labels(content[:labels]),
        fields: field_values(node[:fieldValues]),
        archived: !!node[:isArchived]
      )
    end

    # The four badges a card can wear. A draft has no state of its own, and a
    # pull request has two more than an issue does.
    # :reek:ControlParameter - The union's type is what says which keys to read
    def state_for(typename, content)
      return Item::DRAFT if typename == Item::DRAFT_ISSUE
      return Item::MERGED if content[:merged]
      return Item::DRAFT if content[:isDraft]

      content[:state].to_s.casecmp?("CLOSED") ? Item::CLOSED : Item::OPEN
    end

    # :reek:NilCheck - A value GitHub left out is not a value of nothing
    # :reek:TooManyStatements - One pass that names, types and keeps each value
    def field_values(connection)
      Array(connection&.dig(:nodes)).each_with_object({}) do |node, values|
        name = node.dig(:field, :name)
        key = VALUE_KEYS[node[:__typename].to_s]
        next if name.blank? || key.nil? || IGNORED_FIELDS.include?(name)

        value = node[key]
        values[name] = value unless value.nil?
      end
    end

    def person(node)
      return if node.blank?

      { login: node[:login].to_s, avatar_url: node[:avatarUrl] }
    end

    def people(connection)
      Array(connection&.dig(:nodes)).map { |node| person(node) }
    end

    def labels(connection)
      Array(connection&.dig(:nodes)).map { |node| { name: node[:name].to_s, color: node[:color].to_s } }
    end
  end
end
