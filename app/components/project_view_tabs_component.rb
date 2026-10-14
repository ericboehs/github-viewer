# frozen_string_literal: true

# The strip of saved views across the top of a project, the way GitHub shows
# them.
#
# A project's first view is what it opens on, so that tab links to the project
# itself rather than to `/views/1`, keeping one URL per page.
#
# A view carries its own filter, and the filter box is seeded from it, so
# switching views deliberately drops whatever the user had typed: the point of
# clicking a view is to see that view.
class ProjectViewTabsComponent < ViewComponent::Base
  def initialize(project:, current:)
    @project = project
    @current = current
  end

  def render?
    @project.views.many?
  end

  private

  attr_reader :project, :current

  def views
    project.views
  end

  def first_view?(view)
    views.first == view
  end

  def path_for(view)
    helpers.project_path(project, view: (view.number unless first_view?(view)))
  end

  def current?(view)
    current == view
  end

  def classes(view)
    active = current?(view)

    "-mb-px whitespace-nowrap border-b-2 px-1 pb-2 text-sm font-medium #{
      active ? 'border-emerald-500 text-gray-900 dark:text-white' :
              'border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700 dark:text-gray-400 dark:hover:text-white'
    }"
  end
end
