# frozen_string_literal: true

# One project in a list of them.
#
# Both lists use this: an organization's projects, and the projects a
# repository is linked to. In the second case the project may well belong to a
# different owner than the repository, which is why the owner is named here
# rather than assumed.
class ProjectListItemComponent < ViewComponent::Base
  def initialize(project:)
    @project = project
  end

  private

  attr_reader :project

  def owner_label
    "#{project.owner_login} / ##{project.number}"
  end

  def item_count
    project.item_count
  end
end
