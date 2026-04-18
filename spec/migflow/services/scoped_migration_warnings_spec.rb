# frozen_string_literal: true

require "spec_helper"
require "migflow/services/touched_tables_from_migration"
require "migflow/services/scoped_migration_warnings"

RSpec.describe "ScopedMigrationWarnings" do
  describe Migflow::Services::TouchedTablesFromMigration do
    it "reads touched tables from migration scanner" do
      raw_content = <<~RUBY
        class MixedChanges < ActiveRecord::Migration[7.1]
          def change
            change_column_null :users, :name, true
            remove_index :accounts, :name
            rename_table :old_orders, :orders
          end
        end
      RUBY

      touched_tables = described_class.call(raw_content: raw_content)

      expect(touched_tables).to include("users")
      expect(touched_tables).to include("accounts")
      expect(touched_tables).to include("old_orders")
      expect(touched_tables).to include("orders")
    end
  end

  describe Migflow::Services::ScopedMigrationWarnings do
    def build_snapshot(tables)
      Migflow::Models::MigrationSnapshot.new(
        version: "20260101010101",
        name: "Snapshot",
        raw_content: "",
        tables: tables
      )
    end

    it "filters schema warnings by touched tables" do
      snapshot = build_snapshot(
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

      warnings = described_class.call(snapshot: snapshot, migration: migration)
      tables = warnings.map(&:table).uniq

      expect(tables).to include("users")
      expect(tables).not_to include("posts")
    end

    it "empty migration returns single info warning, not full schema" do
      snapshot = build_snapshot(
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

      warnings = described_class.call(snapshot: snapshot, migration: migration)

      expect(warnings.size).to eq(1)
      expect(warnings.first.rule).to eq("no_schema_change_migration_rule")
      expect(warnings.first.severity).to eq(:info)
    end

    it "migration with execute but no schema DSL skips no-op info warning" do
      snapshot = build_snapshot(
        "users" => {
          columns: [{ name: "name", type: "string", null: true, default: nil }],
          indexes: [],
          foreign_keys: [],
          check_constraints: []
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

      warnings = described_class.call(snapshot: snapshot, migration: migration)

      expect(warnings.none? { |w| w.rule == "no_schema_change_migration_rule" }).to be(true)
    end
  end
end
