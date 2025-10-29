class CreateGithubTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :github_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :domain, null: false, default: "github.com"
      t.text :token, null: false
      t.string :label

      t.timestamps
    end

    add_index :github_tokens, [ :user_id, :domain ], unique: true
  end
end
