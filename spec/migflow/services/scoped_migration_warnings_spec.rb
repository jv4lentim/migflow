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

    context "change-scoped filtering (diff: provided)" do
      def build_snapshot_with(tables)
        Migflow::Models::MigrationSnapshot.new(
          version: "20260101010101",
          name: "Snapshot",
          raw_content: "",
          tables: tables
        )
      end

      it "only warns about newly added columns in a modified table" do
        # Table already had original_filename and content_type before the migration.
        # The migration adds thumb_filename. Only thumb_filename should be flagged.
        snapshot = build_snapshot_with(
          "temp_files" => {
            columns: [
              { name: "original_filename", type: "string", null: true, default: nil },
              { name: "content_type",      type: "string", null: true, default: nil },
              { name: "thumb_filename",    type: "string", null: true, default: nil }
            ],
            indexes: [],
            foreign_keys: [],
            check_constraints: []
          }
        )

        migration = {
          version: "20260101010102",
          filename: "20260101010102_add_thumb_fields.rb",
          raw_content: <<~RUBY
            class AddThumbFields < ActiveRecord::Migration[7.1]
              def change
                add_column :temp_files, :thumb_filename, :string
              end
            end
          RUBY
        }

        diff = {
          added_tables: [],
          removed_tables: [],
          modified_tables: { "temp_files" => { added_columns: ["thumb_filename"], removed_columns: [] } }
        }

        warnings = described_class.call(snapshot: snapshot, migration: migration, diff: diff)
        warned_columns = warnings.map(&:column).compact

        expect(warned_columns).to include("thumb_filename")
        expect(warned_columns).not_to include("original_filename")
        expect(warned_columns).not_to include("content_type")
      end

      it "keeps all warnings for a newly created table" do
        snapshot = build_snapshot_with(
          "orders" => {
            columns: [
              { name: "id",         type: "bigint",  null: false, default: nil },
              { name: "user_id",    type: "integer", null: false, default: nil },
              { name: "created_at", type: "datetime", null: false, default: nil },
              { name: "updated_at", type: "datetime", null: false, default: nil }
            ],
            indexes: [],
            foreign_keys: [],
            check_constraints: []
          }
        )

        migration = {
          version: "20260101010102",
          filename: "20260101010102_create_orders.rb",
          raw_content: <<~RUBY
            class CreateOrders < ActiveRecord::Migration[7.1]
              def change
                create_table :orders do |t|
                  t.references :user
                  t.timestamps
                end
              end
            end
          RUBY
        }

        diff = {
          added_tables: ["orders"],
          removed_tables: [],
          modified_tables: {}
        }

        warnings = described_class.call(snapshot: snapshot, migration: migration, diff: diff)
        warned_tables = warnings.map(&:table).uniq

        expect(warned_tables).to include("orders")
      end

      it "suppresses missing_timestamps_rule for a pre-existing table touched by the migration" do
        snapshot = build_snapshot_with(
          "logs" => {
            columns: [
              { name: "id",      type: "bigint", null: false, default: nil },
              { name: "message", type: "string", null: true,  default: nil },
              { name: "level",   type: "string", null: true,  default: nil }
            ],
            indexes: [],
            foreign_keys: [],
            check_constraints: []
          }
        )

        migration = {
          version: "20260101010102",
          filename: "20260101010102_add_level_to_logs.rb",
          raw_content: <<~RUBY
            class AddLevelToLogs < ActiveRecord::Migration[7.1]
              def change
                add_column :logs, :level, :string
              end
            end
          RUBY
        }

        diff = {
          added_tables: [],
          removed_tables: [],
          modified_tables: { "logs" => { added_columns: ["level"], removed_columns: [] } }
        }

        warnings = described_class.call(snapshot: snapshot, migration: migration, diff: diff)
        rules = warnings.map(&:rule)

        expect(rules).not_to include("missing_timestamps_rule")
      end

      it "keeps missing_timestamps_rule for a newly created table without timestamps" do
        snapshot = build_snapshot_with(
          "events" => {
            columns: [
              { name: "id",    type: "bigint", null: false, default: nil },
              { name: "title", type: "string", null: false, default: nil, limit: 255 }
            ],
            indexes: [],
            foreign_keys: [],
            check_constraints: []
          }
        )

        migration = {
          version: "20260101010102",
          filename: "20260101010102_create_events.rb",
          raw_content: <<~RUBY
            class CreateEvents < ActiveRecord::Migration[7.1]
              def change
                create_table :events do |t|
                  t.string :title, limit: 255
                end
              end
            end
          RUBY
        }

        diff = {
          added_tables: ["events"],
          removed_tables: [],
          modified_tables: {}
        }

        warnings = described_class.call(snapshot: snapshot, migration: migration, diff: diff)
        rules = warnings.map(&:rule)

        expect(rules).to include("missing_timestamps_rule")
      end

      it "does not suppress dangerous_migration_rule regardless of diff" do
        snapshot = build_snapshot_with(
          "users" => {
            columns: [{ name: "id", type: "bigint", null: false, default: nil }],
            indexes: [],
            foreign_keys: [],
            check_constraints: []
          }
        )

        migration = {
          version: "20260101010102",
          filename: "20260101010102_drop_users.rb",
          raw_content: <<~RUBY
            class DropUsers < ActiveRecord::Migration[7.1]
              def change
                drop_table :users
              end
            end
          RUBY
        }

        diff = {
          added_tables: [],
          removed_tables: ["users"],
          modified_tables: {}
        }

        warnings = described_class.call(snapshot: snapshot, migration: migration, diff: diff)
        rules = warnings.map(&:rule)

        expect(rules).to include("dangerous_migration_rule")
      end

      it "does not suppress null_column_without_default_rule regardless of diff" do
        snapshot = build_snapshot_with(
          "orders" => {
            columns: [
              { name: "id",     type: "bigint",  null: false, default: nil },
              { name: "status", type: "integer", null: false, default: nil }
            ],
            indexes: [],
            foreign_keys: [],
            check_constraints: []
          }
        )

        migration = {
          version: "20260101010102",
          filename: "20260101010102_add_status.rb",
          raw_content: <<~RUBY
            class AddStatus < ActiveRecord::Migration[7.1]
              def change
                add_column :orders, :status, :integer, null: false
              end
            end
          RUBY
        }

        diff = {
          added_tables: [],
          removed_tables: [],
          modified_tables: { "orders" => { added_columns: ["status"], removed_columns: [] } }
        }

        warnings = described_class.call(snapshot: snapshot, migration: migration, diff: diff)
        rules = warnings.map(&:rule)

        expect(rules).to include("null_column_without_default_rule")
      end
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

    it "migration with enable_extension skips no-op info warning" do
      snapshot = build_snapshot({})

      migration = {
        version: "20260101010102",
        filename: "20260101010102_enable_uuid.rb",
        raw_content: <<~RUBY
          class EnableUuid < ActiveRecord::Migration[7.1]
            def change
              enable_extension "pgcrypto"
            end
          end
        RUBY
      }

      warnings = described_class.call(snapshot: snapshot, migration: migration)

      expect(warnings.none? { |w| w.rule == "no_schema_change_migration_rule" }).to be(true)
    end

    it "migration with create_extension skips no-op info warning" do
      snapshot = build_snapshot({})

      migration = {
        version: "20260101010102",
        filename: "20260101010102_create_ext.rb",
        raw_content: <<~RUBY
          class CreateExt < ActiveRecord::Migration[7.1]
            def change
              create_extension "hstore"
            end
          end
        RUBY
      }

      warnings = described_class.call(snapshot: snapshot, migration: migration)

      expect(warnings.none? { |w| w.rule == "no_schema_change_migration_rule" }).to be(true)
    end
  end
end
