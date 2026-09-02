# frozen_string_literal: true

# One directory's entries, folders first, in the style of GitHub's Code tab.
class DirectoryListingComponent < ViewComponent::Base
  attr_reader :entries, :repository, :path, :ref

  def initialize(entries:, repository:, path: "", ref: nil)
    @entries = entries
    @repository = repository
    @path = path.to_s
    @ref = ref
    super()
  end

  # nil at the repository root, where there is nowhere to go up to.
  def parent_path
    return if path.blank?

    File.dirname(path).then { |parent| parent == "." ? "" : parent }
  end

  # :reek:UtilityFunction - Reads one entry's shape for the template
  def directory?(entry)
    entry[:type] == "dir"
  end

  # A submodule or symlink has no contents to browse and no blob to read, so it
  # is listed but not linked.
  # :reek:UtilityFunction - Reads one entry's shape for the template
  def navigable?(entry)
    %w[dir file].include?(entry[:type])
  end

  # Sizes are meaningless for directories, which GitHub reports as 0.
  # :reek:UtilityFunction - Reads one entry's shape for the template
  def size_for(entry)
    entry[:type] == "file" ? entry[:size] : nil
  end
end
