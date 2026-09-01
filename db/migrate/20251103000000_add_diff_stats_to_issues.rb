# frozen_string_literal: true

# Pull request diff statistics, so the Conversation/Commits/Files tabs can show
# their counts without an API round-trip per page view.
#
# These come from the pull request endpoint rather than the issue endpoint, and
# stay null for plain issues.
class AddDiffStatsToIssues < ActiveRecord::Migration[8.1]
  def change
    add_column :issues, :commits_count, :integer
    add_column :issues, :changed_files_count, :integer
    add_column :issues, :additions, :integer
    add_column :issues, :deletions, :integer
  end
end
