class RenameRepositoryContributorsToRepositoryAssignableUsers < ActiveRecord::Migration[8.1]
  def change
    rename_table :repository_contributors, :repository_assignable_users

    # Remove columns we don't need for assignable users
    remove_column :repository_assignable_users, :role, :string
    remove_column :repository_assignable_users, :contributions, :integer
  end
end
