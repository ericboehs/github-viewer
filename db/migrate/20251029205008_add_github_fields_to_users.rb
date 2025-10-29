class AddGithubFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :github_token, :text
    add_column :users, :github_domain, :string, default: "github.com", null: false
  end
end
