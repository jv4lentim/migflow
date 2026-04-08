# frozen_string_literal: true

require "test_helper"
require "migflow/services/migration_summary_builder"

class MigrationSummaryBuilderTest < Minitest::Test
  def test_summarizes_create_table
    raw_content = <<~RUBY
      class CreateUsers < ActiveRecord::Migration[7.1]
        def change
          create_table :users do |t|
            t.string :name
          end
        end
      end
    RUBY

    summary = build_summary(raw_content, "20260101010101")

    assert_equal "Created table users", summary
  end

  def test_summarizes_drop_table
    raw_content = <<~RUBY
      class DropUsers < ActiveRecord::Migration[7.1]
        def change
          drop_table :users
        end
      end
    RUBY

    summary = build_summary(raw_content, "20260101010101")

    assert_equal "Dropped table users", summary
  end

  def test_summarizes_added_columns_and_references
    raw_content = <<~RUBY
      class AddFieldsToPosts < ActiveRecord::Migration[7.1]
        def change
          add_column :posts, :title, :string
          add_reference :posts, :author
        end
      end
    RUBY

    summary = build_summary(raw_content, "20260101010101")

    assert_equal "Added title to posts, author_id to posts", summary
  end

  def test_falls_back_to_version_when_no_supported_operation_exists
    raw_content = <<~RUBY
      class Noop < ActiveRecord::Migration[7.1]
        def change
          execute "SELECT 1"
        end
      end
    RUBY

    summary = build_summary(raw_content, "20260101010101")

    assert_equal "Migration 20260101010101", summary
  end

  private

  def build_summary(raw_content, version)
    Migflow::Services::MigrationSummaryBuilder.call(raw_content: raw_content, version: version)
  end
end
