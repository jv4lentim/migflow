# frozen_string_literal: true

require "test_helper"
require "migflow/services/snapshot_builder"

class SnapshotBuilderTest < Minitest::Test
  def test_create_table_references_builds_fk_column
    result = build_snapshot([
      migration("20250000000001", <<~RUBY),
        class CreateAlbums < ActiveRecord::Migration[8.0]
          def change
            create_table :albums do |t|
              t.string :name
            end
          end
        end
      RUBY
      migration("20250000000002", <<~RUBY)
        class CreateTempFiles < ActiveRecord::Migration[8.0]
          def change
            create_table :temp_files do |t|
              t.references :album, null: false, foreign_key: true
            end
          end
        end
      RUBY
    ], "20250000000002")

    columns = result[:schema_after][:tables]["temp_files"][:columns].map { |c| c[:name] }
    assert_includes columns, "album_id"
    refute_includes columns, "album"
    assert_includes result[:diff][:added_tables], "temp_files"
  end

  def test_add_and_remove_reference_methods_are_supported
    migrations = [
      migration("20250000000001", <<~RUBY),
        class CreateTempFiles < ActiveRecord::Migration[8.0]
          def change
            create_table :temp_files do |t|
              t.string :name
            end
          end
        end
      RUBY
      migration("20250000000002", <<~RUBY),
        class AddAlbumToTempFiles < ActiveRecord::Migration[8.0]
          def change
            add_belongs_to :temp_files, :album, null: false
          end
        end
      RUBY
      migration("20250000000003", <<~RUBY)
        class RemoveAlbumFromTempFiles < ActiveRecord::Migration[8.0]
          def change
            remove_reference :temp_files, :album
          end
        end
      RUBY
    ]

    added = build_snapshot(migrations, "20250000000002")
    removed = build_snapshot(migrations, "20250000000003")

    added_columns = added[:schema_after][:tables]["temp_files"][:columns].map { |c| c[:name] }
    removed_columns = removed[:schema_after][:tables]["temp_files"][:columns].map { |c| c[:name] }

    assert_includes added_columns, "album_id"
    refute_includes removed_columns, "album_id"
  end

  def test_change_table_references_and_indexes
    migrations = [
      migration("20250000000001", <<~RUBY),
        class CreateTempFiles < ActiveRecord::Migration[8.0]
          def change
            create_table :temp_files do |t|
              t.string :name
            end
          end
        end
      RUBY
      migration("20250000000002", <<~RUBY),
        class UpdateTempFiles < ActiveRecord::Migration[8.0]
          def change
            change_table :temp_files do |t|
              t.references :album, null: false
              t.index :album_id, name: "index_temp_files_on_album_id"
            end
          end
        end
      RUBY
      migration("20250000000003", <<~RUBY)
        class CleanupTempFiles < ActiveRecord::Migration[8.0]
          def change
            change_table :temp_files do |t|
              t.remove_references :album
              t.remove_index name: "index_temp_files_on_album_id"
            end
          end
        end
      RUBY
    ]

    added = build_snapshot(migrations, "20250000000002")
    removed = build_snapshot(migrations, "20250000000003")

    added_columns = added[:schema_after][:tables]["temp_files"][:columns].map { |c| c[:name] }
    added_indexes = added[:schema_after][:tables]["temp_files"][:indexes]
    removed_columns = removed[:schema_after][:tables]["temp_files"][:columns].map { |c| c[:name] }
    removed_indexes = removed[:schema_after][:tables]["temp_files"][:indexes]

    assert_includes added_columns, "album_id"
    assert_equal "index_temp_files_on_album_id", added_indexes.first[:name]
    refute_includes removed_columns, "album_id"
    assert_empty removed_indexes
  end

  def test_remove_index_standalone_by_columns
    migrations = [
      migration("20250000000001", <<~RUBY),
        class CreateTempFiles < ActiveRecord::Migration[8.0]
          def change
            create_table :temp_files do |t|
              t.string :name
              t.timestamps
            end
            add_index :temp_files, [:name, :created_at], name: "index_temp_files_on_name_and_created_at"
          end
        end
      RUBY
      migration("20250000000002", <<~RUBY)
        class RemoveTempFilesIndex < ActiveRecord::Migration[8.0]
          def change
            remove_index :temp_files, [:name, :created_at]
          end
        end
      RUBY
    ]

    result = build_snapshot(migrations, "20250000000002")
    assert_empty result[:schema_after][:tables]["temp_files"][:indexes]
  end

  def test_create_table_parses_t_column_and_inline_indexes
    result = build_snapshot([
      migration("20250000000001", <<~RUBY)
        class CreateInvoices < ActiveRecord::Migration[8.0]
          def change
            create_table :invoices do |t|
              t.column :amount, :decimal, null: false
              t.string :status
              t.index :status, name: "index_invoices_on_status"
            end
          end
        end
      RUBY
    ], "20250000000001")

    columns = result[:schema_after][:tables]["invoices"][:columns]
    indexes = result[:schema_after][:tables]["invoices"][:indexes]

    amount = columns.find { |c| c[:name] == "amount" }
    assert_equal "decimal", amount[:type]
    assert_equal false, amount[:null]
    assert_equal "index_invoices_on_status", indexes.first[:name]
  end

  def test_supports_change_column_default_and_null_and_rename_index
    migrations = [
      migration("20250000000001", <<~RUBY),
        class CreateInvoices < ActiveRecord::Migration[8.0]
          def change
            create_table :invoices do |t|
              t.string :status
              t.index :status, name: "index_invoices_on_status"
            end
          end
        end
      RUBY
      migration("20250000000002", <<~RUBY)
        class ChangeInvoiceColumns < ActiveRecord::Migration[8.0]
          def change
            change_column_default :invoices, :status, "pending"
            change_column_null :invoices, :status, false
            rename_index :invoices, :index_invoices_on_status, :index_invoices_on_state
          end
        end
      RUBY
    ]

    result = build_snapshot(migrations, "20250000000002")
    table = result[:schema_after][:tables]["invoices"]
    status = table[:columns].find { |c| c[:name] == "status" }

    assert_equal "pending", status[:default]
    assert_equal false, status[:null]
    assert_equal "index_invoices_on_state", table[:indexes].first[:name]
  end

  def test_supports_remove_columns_and_remove_references_plural
    migrations = [
      migration("20250000000001", <<~RUBY),
        class CreateInvoices < ActiveRecord::Migration[8.0]
          def change
            create_table :invoices do |t|
              t.references :account
              t.string :status
              t.string :legacy_code
            end
          end
        end
      RUBY
      migration("20250000000002", <<~RUBY)
        class CleanupInvoices < ActiveRecord::Migration[8.0]
          def change
            remove_columns :invoices, :status, :legacy_code
            remove_references :invoices, :account
          end
        end
      RUBY
    ]

    result = build_snapshot(migrations, "20250000000002")
    columns = result[:schema_after][:tables]["invoices"][:columns].map { |c| c[:name] }

    refute_includes columns, "status"
    refute_includes columns, "legacy_code"
    refute_includes columns, "account_id"
  end

  def test_change_table_supports_column_changes_and_rename_index
    migrations = [
      migration("20250000000001", <<~RUBY),
        class CreateInvoices < ActiveRecord::Migration[8.0]
          def change
            create_table :invoices do |t|
              t.string :status
              t.index :status, name: "index_invoices_on_status"
            end
          end
        end
      RUBY
      migration("20250000000002", <<~RUBY)
        class RefactorInvoices < ActiveRecord::Migration[8.0]
          def change
            change_table :invoices do |t|
              t.column :amount, :integer, null: false
              t.change_default :status, "open"
              t.change_null :status, false
              t.rename_index :index_invoices_on_status, :index_invoices_on_state
              t.remove_columns :amount
            end
          end
        end
      RUBY
    ]

    result = build_snapshot(migrations, "20250000000002")
    table = result[:schema_after][:tables]["invoices"]
    status = table[:columns].find { |c| c[:name] == "status" }
    columns = table[:columns].map { |c| c[:name] }

    assert_equal "open", status[:default]
    assert_equal false, status[:null]
    assert_equal "index_invoices_on_state", table[:indexes].first[:name]
    refute_includes columns, "amount"
  end

  def test_supports_foreign_key_and_check_constraint_lifecycle
    migrations = [
      migration("20250000000001", <<~RUBY),
        class CreateInvoices < ActiveRecord::Migration[8.0]
          def change
            create_table :invoices do |t|
              t.integer :amount
            end
          end
        end
      RUBY
      migration("20250000000002", <<~RUBY),
        class AddConstraints < ActiveRecord::Migration[8.0]
          def change
            add_foreign_key :invoices, :accounts, column: :account_id, name: "fk_invoices_accounts"
            add_check_constraint :invoices, "amount > 0", name: "amount_positive"
          end
        end
      RUBY
      migration("20250000000003", <<~RUBY)
        class RemoveConstraints < ActiveRecord::Migration[8.0]
          def change
            remove_foreign_key :invoices, name: "fk_invoices_accounts"
            remove_check_constraint :invoices, name: "amount_positive"
          end
        end
      RUBY
    ]

    with_constraints = build_snapshot(migrations, "20250000000002")
    without_constraints = build_snapshot(migrations, "20250000000003")

    table_with = with_constraints[:schema_after][:tables]["invoices"]
    table_without = without_constraints[:schema_after][:tables]["invoices"]

    assert_equal "fk_invoices_accounts", table_with[:foreign_keys].first[:name]
    assert_equal "amount_positive", table_with[:check_constraints].first[:name]
    assert_empty table_without[:foreign_keys]
    assert_empty table_without[:check_constraints]
  end

  def test_supports_change_column_comment
    migrations = [
      migration("20250000000001", <<~RUBY),
        class CreateInvoices < ActiveRecord::Migration[8.0]
          def change
            create_table :invoices do |t|
              t.string :status
            end
          end
        end
      RUBY
      migration("20250000000002", <<~RUBY)
        class CommentInvoiceStatus < ActiveRecord::Migration[8.0]
          def change
            change_column_comment :invoices, :status, "Current workflow state"
          end
        end
      RUBY
    ]

    result = build_snapshot(migrations, "20250000000002")
    status = result[:schema_after][:tables]["invoices"][:columns].find { |c| c[:name] == "status" }

    assert_equal "Current workflow state", status[:comment]
  end

  def test_add_column_supports_parenthesized_syntax
    migrations = [
      migration("20250000000001", <<~RUBY),
        class CreatePetsDashboards < ActiveRecord::Migration[8.0]
          def change
            create_table :pets_dashboards do |t|
              t.string :name
            end
          end
        end
      RUBY
      migration("20250000000002", <<~RUBY)
        class AddLastUpdatedAtToPetsDashboard < ActiveRecord::Migration[8.0]
          def change
            add_column(:pets_dashboards, :last_updated_at, :date)
          end
        end
      RUBY
    ]

    result = build_snapshot(migrations, "20250000000002")
    columns = result[:schema_after][:tables]["pets_dashboards"][:columns].map { |c| c[:name] }

    assert_includes columns, "last_updated_at"
    assert_equal ["last_updated_at"], result[:diff][:modified_tables]["pets_dashboards"][:added_columns]
  end

  private

  def migration(version, raw_content)
    { version: version, raw_content: raw_content }
  end

  def build_snapshot(migrations, up_to_version)
    Migflow::Services::SnapshotBuilder.call(migrations: migrations, up_to_version: up_to_version)
  end
end
