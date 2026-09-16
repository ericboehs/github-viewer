# frozen_string_literal: true

module Projects
  # GitHub's project filter syntax, parsed and applied here.
  #
  #   status:Todo,"In Progress" -label:blocked assignee:@me sprint:@current login
  #
  # `ProjectV2.items` takes no filter argument, so a filtered board is the
  # whole board fetched and then narrowed in Ruby. That is the reason this
  # exists rather than a query string being forwarded to the API.
  #
  # The rules are GitHub's:
  #
  # * qualifiers are ANDed, and repeating one ANDs it again (`label:a label:b`
  #   is both labels)
  # * commas within one qualifier are ORed (`status:Todo,Done`)
  # * a leading `-` negates (`-label:blocked`)
  # * anything that is not a qualifier is matched against the title
  #
  # A qualifier is either one of the built-in names below or the name of one of
  # the project's own fields, which is why a Filter is built against a Project:
  # `sprint:@current` cannot be resolved without knowing that Sprint is an
  # iteration field and which of its iterations contains today.
  #
  # :reek:TooManyMethods - One predicate per qualifier reads better than one case
  # :reek:DataClump - Every matcher below is (what was typed, the item to test it against)
  # :reek:NilCheck - A missing value and an empty one are different answers here
  # :reek:UtilityFunction - Matchers that happen not to need the project are still matchers
  class Filter
    # A single qualifier, or one bare word of the title search.
    Term = Data.define(:key, :values, :negated)

    # Splits on whitespace but not inside quotes, so `status:"In Progress"`
    # survives as one token.
    TOKEN = /(?:"[^"]*"|[^\s"])+/

    # Qualifiers about the item itself rather than about a project field.
    BUILT_IN = %w[is no assignee label author repo].freeze

    # `@me` is the account the token belongs to, which the project query asks
    # GitHub for as `viewer`.
    VIEWER = "@me"

    # `@current` is whichever iteration contains today.
    CURRENT_ITERATION = "@current"

    attr_reader :query, :project, :terms

    def initialize(query, project:)
      @query = query.to_s
      @project = project
      @terms = parse
    end

    def empty?
      terms.empty?
    end

    # Qualifiers that name neither a built-in nor one of this project's fields.
    # They match nothing, which would otherwise look like an empty project, so
    # the page says so instead.
    def unknown_keys
      terms.map(&:key).uniq.select { |key| unknown?(key) }
    end

    def match?(item)
      terms.all? { |term| matches_term?(term, item) }
    end

    def apply(items)
      return items if empty?

      items.select { |item| match?(item) }
    end

    private

    def parse
      query.scan(TOKEN).filter_map { |token| term_for(token) }
    end

    # :reek:TooManyStatements - Splits one token into negation, key and values
    def term_for(token)
      negated = token.start_with?("-")
      body = negated ? token[1..] : token
      key, _, raw_values = body.partition(":")

      return bare_term(body, negated) if raw_values.blank?

      Term.new(key: key.downcase.delete('"'), values: split_values(raw_values), negated: negated)
    end

    # A word with no colon in it searches the title. A lone `-` or `""` is not
    # a search for anything.
    def bare_term(body, negated)
      text = unquote(body)
      return if text.blank?

      Term.new(key: nil, values: [ text ], negated: negated)
    end

    def split_values(raw_values)
      raw_values.scan(/(?:"[^"]*"|[^,"])+/).filter_map { |value| unquote(value).presence }
    end

    def unquote(value)
      value.to_s.gsub(/\A["']|["']\z/, "")
    end

    def unknown?(key)
      key.present? && !BUILT_IN.include?(key) && project.field_for_key(key).nil?
    end

    # Negation is "none of the values matched", so both directions come from
    # the same positive test.
    #
    # :reek:FeatureEnvy - Reads a term to decide what asking it of an item means
    def matches_term?(term, item)
      matched = term.values.any? { |value| matches_value?(term.key, value, item) }

      term.negated ? !matched : matched
    end

    # :reek:TooManyStatements - One branch per built-in qualifier
    def matches_value?(key, value, item)
      case key
      when nil then item.title.downcase.include?(value.downcase)
      when "is" then matches_is?(value, item)
      when "no" then missing?(value, item)
      when "assignee" then matches_login?(item.assignee_logins, value)
      when "label" then item.label_names.any? { |name| same?(name, value) }
      when "author" then matches_login?([ item.author&.dig(:login) ], value)
      when "repo" then matches_repository?(item.repository, value)
      else matches_field?(key, value, item)
      end
    end

    # :reek:TooManyStatements - One branch per recognised `is:` value
    def matches_is?(value, item)
      case value.downcase
      when "issue" then item.issue?
      when "pr", "pull-request" then item.pull_request?
      when "draft" then item.state == Item::DRAFT
      when "merged" then item.merged?
      when "open" then item.open?
      when "closed" then item.closed?
      else false
      end
    end

    # `@me` is whoever the token belongs to, so it is resolved once rather than
    # per login.
    def matches_login?(logins, value)
      wanted = resolve(value)

      logins.any? { |login| same?(login, wanted) }
    end

    # GitHub accepts a repository by name alone as well as with its owner.
    def matches_repository?(full_name, value)
      same?(full_name, value) || same?(full_name.to_s.split("/").last, value)
    end

    # `no:status` is GitHub's spelling for the board's "No Status" column, and
    # works for the built-in lists too.
    # :reek:FeatureEnvy - Asks the item what it is missing
    def missing?(value, item)
      case value.downcase
      when "assignee" then item.assignees.empty?
      when "label" then item.labels.empty?
      else field_value(value, item).blank?
      end
    end

    def matches_field?(key, value, item)
      field = project.field_for_key(key)
      return false unless field

      same?(item.field_value(field.name), expand(field, value))
    end

    def field_value(key, item)
      field = project.field_for_key(key)

      field ? item.field_value(field.name) : nil
    end

    # `@current` only means anything against an iteration field.
    def expand(field, value)
      return field.current_iteration&.title if value.casecmp?(CURRENT_ITERATION) && field.iteration?

      value
    end

    def resolve(value)
      value.casecmp?(VIEWER) ? project.viewer_login : value
    end

    # Field values arrive as numbers as well as strings, and `estimate:3`
    # should find the item GitHub stored as 3.0.
    def same?(left, right)
      return false if left.nil? || right.nil?

      normalize(left).casecmp?(normalize(right))
    end

    # :reek:FeatureEnvy - Formats the value it is handed
    def normalize(value)
      return format("%g", value) if value.is_a?(Numeric)

      value.to_s
    end
  end
end
