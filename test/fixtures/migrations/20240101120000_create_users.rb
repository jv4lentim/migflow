class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users do |t|
      t.string :email, null: false, limit: 255
      t.string :name, null: false, limit: 100
      t.integer :role, default: 0

      t.timestamps
    end

    add_index :users, :email, unique: true, name: "index_users_on_email"
  end
end
