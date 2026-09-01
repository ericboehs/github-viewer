# frozen_string_literal: true

# Conversation / Commits / Files changed sub-navigation for a pull request,
# mirroring GitHub's own.
#
# Counts come from the cached issue record rather than a live call, so the tabs
# render the same on every page without three API round-trips. A nil count
# means we have never synced the pull request endpoint for this record, in
# which case the badge is omitted rather than shown as a misleading zero.
class PullRequestTabsComponent < ViewComponent::Base
  # rubocop:disable Layout/LineLength
  ICONS = {
    conversation: "M1.75 1h12.5c.966 0 1.75.784 1.75 1.75v9.5A1.75 1.75 0 0 1 14.25 14H8.061l-2.574 2.573A1.458 1.458 0 0 1 3 15.543V14H1.75A1.75 1.75 0 0 1 0 12.25v-9.5C0 1.784.784 1 1.75 1Z",
    commits: "M11.93 8.5a4.002 4.002 0 0 1-7.86 0H.75a.75.75 0 0 1 0-1.5h3.32a4.002 4.002 0 0 1 7.86 0h3.32a.75.75 0 0 1 0 1.5Zm-1.43-.75a2.5 2.5 0 1 0-5 0 2.5 2.5 0 0 0 5 0Z",
    files: "M2 1.75C2 .784 2.784 0 3.75 0h6.586c.464 0 .909.184 1.237.513l2.914 2.914c.329.328.513.773.513 1.237v9.586A1.75 1.75 0 0 1 13.25 16h-9.5A1.75 1.75 0 0 1 2 14.25Zm8.75.75h-7a.25.25 0 0 0-.25.25v11.5c0 .138.112.25.25.25h9.5a.25.25 0 0 0 .25-.25V5h-2.5a.25.25 0 0 1-.25-.25Z"
  }.freeze

  ACTIVE_CLASSES = "border-emerald-500 text-gray-900 dark:text-white"
  INACTIVE_CLASSES = "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700 dark:text-gray-400 dark:hover:text-white"
  # rubocop:enable Layout/LineLength

  attr_reader :issue, :repository, :current_tab

  def initialize(issue:, repository:, current_tab:)
    @issue = issue
    @repository = repository
    @current_tab = current_tab
    super()
  end

  def tabs
    number = issue.number

    [
      tab(:conversation, repository_pull_path(repository, number), issue.comments_count),
      tab(:commits, commits_repository_pull_path(repository, number), issue.commits_count),
      tab(:files, files_repository_pull_path(repository, number), issue.changed_files_count)
    ]
  end

  # The diffstat GitHub shows on the right of the tab bar. Suppressed until we
  # have synced the pull request endpoint, since 0/0 reads as "no changes"
  # rather than "not known yet".
  def diffstat?
    issue.additions.present? || issue.deletions.present?
  end

  def additions
    issue.additions.to_i
  end

  def deletions
    issue.deletions.to_i
  end

  private

  def tab(key, path, count)
    {
      key: key,
      label: I18n.t("pulls.tabs.#{key}"),
      path: path,
      count: count,
      icon: ICONS.fetch(key),
      active: current_tab == key
    }
  end
end
