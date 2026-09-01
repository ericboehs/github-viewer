class AddPullRequestToIssues < ActiveRecord::Migration[8.1]
  def change
    add_column :issues, :pull_request, :boolean, default: false, null: false
    add_column :issues, :draft, :boolean, default: false, null: false
    add_column :issues, :merged_at, :datetime

    add_index :issues, [ :repository_id, :pull_request ]
  end
end
