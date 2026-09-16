# frozen_string_literal: true

module Projects
  # A GitHub Projects V2 project, as much of it as a reader needs.
  #
  # Projects belong to an organization or to a user rather than to a
  # repository - a repository only links to them - which is why this carries
  # its own owner and host instead of a Repository, and why its URLs are built
  # from those three values by ProjectUrls.
  #
  # Nothing here is persisted. Project data is read live on each request, the
  # way branches and commits are, so this is the shape the GraphQL response is
  # turned into and not a record.
  #
  # `viewer_login` is the signed-in account on the *GitHub* side, which the
  # filter `assignee:@me` needs and this application does not otherwise store.
  #
  # :reek:TooManyInstanceVariables - A project is a wide record; this is its shape
  Project = Data.define(
    :id, :number, :title, :short_description, :url, :closed, :public,
    :owner_login, :owner_type, :github_domain, :item_count, :updated_at,
    :fields, :views, :viewer_login
  ) do
    # :reek:TooManyStatements - Unpacks one node into the whole record
    # :reek:LongParameterList - Domain and viewer come from the request, not the node
    def self.from_graphql(node, github_domain:, viewer_login: nil)
      owner = node[:owner] || {}
      updated_at = node[:updatedAt]

      new(
        id: node[:id],
        number: node[:number].to_i,
        title: node[:title].to_s,
        short_description: node[:shortDescription].presence,
        url: node[:url],
        closed: !!node[:closed],
        public: !!node[:public],
        owner_login: owner[:login].to_s,
        owner_type: ProjectUrls.owner_type_for(owner[:__typename]),
        github_domain: github_domain,
        item_count: node.dig(:items, :totalCount),
        updated_at: (Time.zone.parse(updated_at) if updated_at.present?),
        fields: Array(node.dig(:fields, :nodes)).filter_map { |field| field_from(field) },
        views: Array(node.dig(:views, :nodes)).map { |view| View.from_graphql(view) },
        viewer_login: viewer_login
      )
    end

    # The field configuration union answers with `{}` for any member this
    # query did not spread, so an unnamed node is a field type we do not read
    # rather than a malformed one.
    def self.field_from(node)
      Field.from_graphql(node) if node[:name].present?
    end

    # GitHub opens a project on its first view, and every project has at
    # least one.
    def default_view
      views.first
    end

    # :reek:FeatureEnvy - Compares the number it is given against each view's
    def view(number)
      views.find { |view| view.number == number.to_i } if number.present?
    end

    # :reek:FeatureEnvy - Compares the name it is given against each field's
    def field(name)
      fields.find { |field| field.name.casecmp?(name.to_s) } if name.present?
    end

    # The field a filter qualifier names, matched the way people type it.
    def field_for_key(key)
      downcased = key.to_s.downcase

      fields.find { |field| field.keys.include?(downcased) }
    end
  end
end
