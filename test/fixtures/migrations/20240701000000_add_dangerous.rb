# frozen_string_literal: true

class AddDangerous < ActiveRecord::Migration[7.0]
  def change
    remove_column :users, :role
    rename_column :posts, :body, :content
  end
end
