class CreateRepositoryContributors < ActiveRecord::Migration[8.1]
  def change
    create_table :repository_contributors do |t|
      t.references :repository, null: false, foreign_key: true
      t.string :login, null: false
      t.string :avatar_url
      t.integer :contributions, default: 0
      t.string :role, null: false # 'author' or 'assignee' or 'both'

      t.timestamps
    end

    # Composite unique index to prevent duplicate contributors per repository
    add_index :repository_contributors, [ :repository_id, :login ], unique: true

    # Index for fast search queries
    add_index :repository_contributors, :login
  end
end
