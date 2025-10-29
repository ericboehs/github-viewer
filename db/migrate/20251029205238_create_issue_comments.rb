class CreateIssueComments < ActiveRecord::Migration[8.1]
  def change
    create_table :issue_comments do |t|
      t.references :issue, null: false, foreign_key: true
      t.bigint :github_id, null: false
      t.string :author_login
      t.string :author_avatar_url
      t.text :body
      t.datetime :github_created_at
      t.datetime :github_updated_at

      t.timestamps
    end

    add_index :issue_comments, [ :issue_id, :github_id ], unique: true
  end
end
