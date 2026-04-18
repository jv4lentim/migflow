# frozen_string_literal: true

require "spec_helper"
require "migflow/services/migration_summary_builder"

RSpec.describe Migflow::Services::MigrationSummaryBuilder do
  def build_summary(raw_content, version)
    described_class.call(raw_content: raw_content, version: version)
  end

  it "summarizes create_table" do
    raw_content = <<~RUBY
      class CreateUsers < ActiveRecord::Migration[7.1]
        def change
          create_table :users do |t|
            t.string :name
          end
        end
      end
    RUBY

    expect(build_summary(raw_content, "20260101010101")).to eq("Created table users")
  end

  it "summarizes drop_table" do
    raw_content = <<~RUBY
      class DropUsers < ActiveRecord::Migration[7.1]
        def change
          drop_table :users
        end
      end
    RUBY

    expect(build_summary(raw_content, "20260101010101")).to eq("Dropped table users")
  end

  it "summarizes added columns and references" do
    raw_content = <<~RUBY
      class AddFieldsToPosts < ActiveRecord::Migration[7.1]
        def change
          add_column :posts, :title, :string
          add_reference :posts, :author
        end
      end
    RUBY

    expect(build_summary(raw_content, "20260101010101")).to eq("Added title to posts, author_id to posts")
  end

  it "falls back to version when no supported operation exists" do
    raw_content = <<~RUBY
      class Noop < ActiveRecord::Migration[7.1]
        def change
          execute "SELECT 1"
        end
      end
    RUBY

    expect(build_summary(raw_content, "20260101010101")).to eq("Migration 20260101010101")
  end

  it "summarizes multiple create_table blocks" do
    raw_content = <<~RUBY
      class CreateUsersAndPosts < ActiveRecord::Migration[7.1]
        def change
          create_table :users do |t|
            t.string :name
          end
          create_table :posts do |t|
            t.string :title
          end
        end
      end
    RUBY

    expect(build_summary(raw_content, "20260101010101")).to eq("Created table users, posts")
  end

  it "summarizes multiple drop_table blocks" do
    raw_content = <<~RUBY
      class DropLegacyTables < ActiveRecord::Migration[7.1]
        def change
          drop_table :old_users
          drop_table :old_posts
        end
      end
    RUBY

    expect(build_summary(raw_content, "20260101010101")).to eq("Dropped table old_users, old_posts")
  end

  it "create_table takes priority over add_column" do
    raw_content = <<~RUBY
      class MixedOps < ActiveRecord::Migration[7.1]
        def change
          create_table :widgets do |t|
            t.string :name
          end
          add_column :widgets, :color, :string
        end
      end
    RUBY

    expect(build_summary(raw_content, "20260101010101")).to eq("Created table widgets")
  end
end
