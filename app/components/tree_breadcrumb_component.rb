# frozen_string_literal: true

# The owner/repo/dir/dir trail above a file browser listing, each segment a
# link back up the tree.
class TreeBreadcrumbComponent < ViewComponent::Base
  attr_reader :repository, :path, :ref

  def initialize(repository:, path: "", ref: nil)
    @repository = repository
    @path = path.to_s
    @ref = ref
    super()
  end

  # Each segment paired with the path that reaches it, so the last entry of
  # ["app", "models", "issue.rb"] links to "app/models/issue.rb".
  # :reek:FeatureEnvy - Pure transformation of the path into link targets
  def crumbs
    segments = path.split("/").reject(&:blank?)

    segments.each_with_index.map do |segment, index|
      [ segment, segments[0..index].join("/") ]
    end
  end

  # The final crumb is the page you are already on, so it is not a link.
  def leaf?(index)
    index == crumbs.length - 1
  end
end
