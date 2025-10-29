class CreateIssues < ActiveRecord::Migration[8.1]
  def change
    create_table :issues do |t|
      t.references :repository, null: false, foreign_key: true
      t.integer :number, null: false
      t.string :title, null: false
      t.string :state, null: false
      t.text :body
      t.string :author_login
      t.string :author_avatar_url
      t.json :labels, default: []
      t.json :assignees, default: []
      t.integer :comments_count, default: 0, null: false
      t.datetime :github_created_at
      t.datetime :github_updated_at
      t.datetime :cached_at

      t.timestamps
    end

    add_index :issues, [ :repository_id, :number ], unique: true
    add_index :issues, [ :repository_id, :state ]
  end
end
