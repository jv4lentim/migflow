# frozen_string_literal: true

class AddPosts < ActiveRecord::Migration[7.0]
  def change
    create_table :posts do |t|
      t.string :title, null: false
      t.text :body
      t.integer :user_id, null: false

      t.timestamps
    end
  end
end
