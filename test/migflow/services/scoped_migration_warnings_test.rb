# frozen_string_literal: true

require "test_helper"
require "migflow/services/touched_tables_from_migration"
require "migflow/services/scoped_migration_warnings"

class ScopedMigrationWarningsTest < Minitest::Test
  def test_touched_tables_from_migration_reads_tables_from_scanner
    raw_content = <<~RUBY
      class MixedChanges < ActiveRecord::Migration[7.1]
        def change
          change_column_null :users, :name, true
          remove_index :accounts, :name
          rename_table :old_orders, :orders
        end
      end
    RUBY

    touched_tables = Migflow::Services::TouchedTablesFromMigration.call(raw_content: raw_content)

    assert_includes touched_tables, "users"
    assert_includes touched_tables, "accounts"
    assert_includes touched_tables, "old_orders"
    assert_includes touched_tables, "orders"
  end

  def test_scoped_migration_warnings_filters_schema_warnings_by_touched_tables
    snapshot = Migflow::Models::MigrationSnapshot.new(
      version: "20260101010101",
      name: "Snapshot",
      raw_content: "",
      tables: {
        "users" => {
          columns: [{ name: "name", type: "string", null: true, default: nil }],
          indexes: [],
          foreign_keys: [],
          check_constraints: []
        },
        "posts" => {
          columns: [{ name: "title", type: "string", null: true, default: nil }],
          indexes: [],
          foreign_keys: [],
          check_constraints: []
        }
      }
    )

    migration = {
      version: "20260101010102",
      filename: "20260101010102_change_user_name_null.rb",
      raw_content: <<~RUBY
        class ChangeUserNameNull < ActiveRecord::Migration[7.1]
          def change
            change_column_null :users, :name, true
          end
        end
      RUBY
    }

    warnings = Migflow::Services::ScopedMigrationWarnings.call(snapshot: snapshot, migration: migration)
    tables = warnings.map(&:table).uniq

    assert_includes tables, "users"
    refute_includes tables, "posts"
  end

  def test_empty_migration_returns_single_info_warning_not_full_schema
    snapshot = Migflow::Models::MigrationSnapshot.new(
      version: "20260101010101",
      name: "Snapshot",
      raw_content: "",
      tables: {
        "users" => {
          columns: [{ name: "name", type: "string", null: true, default: nil }],
          indexes: [],
          foreign_keys: [],
          check_constraints: []
        },
        "posts" => {
          columns: [{ name: "title", type: "string", null: true, default: nil }],
          indexes: [],
          foreign_keys: [],
          check_constraints: []
        }
      }
    )

    migration = {
      version: "20260101010102",
      filename: "20260101010102_empty.rb",
      raw_content: <<~RUBY
        class MakeIndicatorIdNullableOnIndicatorCardItems < ActiveRecord::Migration[7.1]
          def change
          end
        end
      RUBY
    }

    warnings = Migflow::Services::ScopedMigrationWarnings.call(snapshot: snapshot, migration: migration)

    assert_equal 1, warnings.size
    assert_equal "no_schema_change_migration_rule", warnings.first.rule
    assert_equal :info, warnings.first.severity
  end

  def test_no_schema_dsl_but_execute_skips_noop_info
    snapshot = Migflow::Models::MigrationSnapshot.new(
      version: "20260101010101",
      name: "Snapshot",
      raw_content: "",
      tables: {
        "users" => {
          columns: [{ name: "name", type: "string", null: true, default: nil }],
          indexes: [],
          foreign_keys: [],
          check_constraints: []
        }
      }
    )

    migration = {
      version: "20260101010102",
      filename: "20260101010102_data.rb",
      raw_content: <<~RUBY
        class SeedSomething < ActiveRecord::Migration[7.1]
          def change
            execute "UPDATE users SET name = 'x'"
          end
        end
      RUBY
    }

    warnings = Migflow::Services::ScopedMigrationWarnings.call(snapshot: snapshot, migration: migration)

    refute(warnings.any? { |w| w.rule == "no_schema_change_migration_rule" })
  end
end
