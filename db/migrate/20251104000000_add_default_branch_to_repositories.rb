# frozen_string_literal: true

# GitHub-shaped tree URLs name a ref (/owner/repo/tree/main/app), so browsing
# below the repository root needs to know the default branch.
class AddDefaultBranchToRepositories < ActiveRecord::Migration[8.1]
  def change
    add_column :repositories, :default_branch, :string
  end
end
