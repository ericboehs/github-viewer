class AddGithubDomainToRepositories < ActiveRecord::Migration[8.1]
  def change
    add_column :repositories, :github_domain, :string, null: false, default: "github.com"

    # Remove old unique index
    remove_index :repositories, name: "index_repositories_on_user_id_and_owner_and_name"

    # Add new unique index including github_domain
    add_index :repositories, [ :user_id, :github_domain, :owner, :name ], unique: true
  end
end
