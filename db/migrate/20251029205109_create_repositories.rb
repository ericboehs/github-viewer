class CreateRepositories < ActiveRecord::Migration[8.1]
  def change
    create_table :repositories do |t|
      t.references :user, null: false, foreign_key: true
      t.string :owner, null: false
      t.string :name, null: false
      t.string :full_name, null: false
      t.text :description
      t.string :url
      t.datetime :cached_at
      t.integer :issue_count, default: 0, null: false
      t.integer :open_issue_count, default: 0, null: false

      t.timestamps
    end

    add_index :repositories, [ :user_id, :owner, :name ], unique: true
  end
end
