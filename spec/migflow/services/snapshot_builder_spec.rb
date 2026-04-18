# frozen_string_literal: true

require "spec_helper"
require "migflow/services/snapshot_builder"

RSpec.describe Migflow::Services::SnapshotBuilder do
  def migration(version, raw_content)
    { version: version, raw_content: raw_content }
  end

  def build_snapshot(migrations, up_to_version)
    described_class.call(migrations: migrations, up_to_version: up_to_version)
  end

  describe "create_table" do
    it "with references builds foreign key column" do
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
      expect(columns).to include("album_id")
      expect(columns).not_to include("album")
      expect(result[:diff][:added_tables]).to include("temp_files")
    end

    it "parses t.column and inline indexes" do
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
      expect(amount[:type]).to eq("decimal")
      expect(amount[:null]).to eq(false)
      expect(indexes.first[:name]).to eq("index_invoices_on_status")
    end
  end

  describe "add_reference / remove_reference" do
    it "add_belongs_to and remove_reference are supported" do
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

      expect(added[:schema_after][:tables]["temp_files"][:columns].map { |c| c[:name] }).to include("album_id")
      expect(removed[:schema_after][:tables]["temp_files"][:columns].map { |c| c[:name] }).not_to include("album_id")
    end

    it "add_reference with custom type" do
      migrations = [
        migration("1", <<~RUBY),
          class CreateNotes < ActiveRecord::Migration[8.0]
            def change
              create_table :notes do |t|
                t.string :title
              end
            end
          end
        RUBY
        migration("2", <<~RUBY)
          class AddAuthorToNotes < ActiveRecord::Migration[8.0]
            def change
              add_reference :notes, :author, type: :uuid, null: false
            end
          end
        RUBY
      ]

      result = build_snapshot(migrations, "2")
      col = result[:schema_after][:tables]["notes"][:columns].find { |c| c[:name] == "author_id" }
      expect(col[:type]).to eq("uuid")
      expect(col[:null]).to eq(false)
    end

    it "add_reference with null: false" do
      migrations = [
        migration("1", <<~RUBY),
          class CreateComments < ActiveRecord::Migration[8.0]
            def change
              create_table :comments do |t|
                t.string :body
              end
            end
          end
        RUBY
        migration("2", <<~RUBY)
          class AddPostToComments < ActiveRecord::Migration[8.0]
            def change
              add_reference :comments, :post, null: false
            end
          end
        RUBY
      ]

      result = build_snapshot(migrations, "2")
      col = result[:schema_after][:tables]["comments"][:columns].find { |c| c[:name] == "post_id" }
      expect(col[:null]).to eq(false)
    end

    it "polymorphic reference adds type column" do
      migrations = [
        migration("1", <<~RUBY),
          class CreateActivities < ActiveRecord::Migration[8.0]
            def change
              create_table :activities do |t|
                t.string :action
              end
            end
          end
        RUBY
        migration("2", <<~RUBY)
          class AddTrackableToActivities < ActiveRecord::Migration[8.0]
            def change
              add_reference :activities, :trackable, polymorphic: true, null: true
            end
          end
        RUBY
      ]

      result = build_snapshot(migrations, "2")
      cols = result[:schema_after][:tables]["activities"][:columns].map { |c| c[:name] }
      expect(cols).to include("trackable_id")
      expect(cols).to include("trackable_type")
    end

    it "remove_columns and remove_references plural" do
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

      expect(columns).not_to include("status")
      expect(columns).not_to include("legacy_code")
      expect(columns).not_to include("account_id")
    end
  end

  describe "change_table" do
    it "handles references and indexes" do
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

      expect(added[:schema_after][:tables]["temp_files"][:columns].map { |c| c[:name] }).to include("album_id")
      expect(added[:schema_after][:tables]["temp_files"][:indexes].first[:name]).to eq("index_temp_files_on_album_id")
      expect(removed[:schema_after][:tables]["temp_files"][:columns].map { |c| c[:name] }).not_to include("album_id")
      expect(removed[:schema_after][:tables]["temp_files"][:indexes]).to be_empty
    end

    it "supports column changes and rename_index" do
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

      expect(status[:default]).to eq("open")
      expect(status[:null]).to eq(false)
      expect(table[:indexes].first[:name]).to eq("index_invoices_on_state")
      expect(table[:columns].map { |c| c[:name] }).not_to include("amount")
    end

    it "supports check_constraint lifecycle" do
      migrations = [
        migration("1", <<~RUBY),
          class CreateInvoices < ActiveRecord::Migration[8.0]
            def change
              create_table :invoices do |t|
                t.integer :amount
              end
            end
          end
        RUBY
        migration("2", <<~RUBY),
          class AddCheckConstraint < ActiveRecord::Migration[8.0]
            def change
              change_table :invoices do |t|
                t.check_constraint "amount > 0", name: "amount_positive"
              end
            end
          end
        RUBY
        migration("3", <<~RUBY)
          class RemoveCheckConstraint < ActiveRecord::Migration[8.0]
            def change
              change_table :invoices do |t|
                t.remove_check_constraint name: "amount_positive"
              end
            end
          end
        RUBY
      ]

      with_cc = build_snapshot(migrations, "2")
      without_cc = build_snapshot(migrations, "3")
      expect(with_cc[:schema_after][:tables]["invoices"][:check_constraints].size).to eq(1)
      expect(without_cc[:schema_after][:tables]["invoices"][:check_constraints]).to be_empty
    end

    it "add_reference polymorphic" do
      migrations = [
        migration("1", <<~RUBY),
          class CreateAttachments < ActiveRecord::Migration[8.0]
            def change
              create_table :attachments do |t|
                t.string :filename
              end
            end
          end
        RUBY
        migration("2", <<~RUBY)
          class AddRecordToAttachments < ActiveRecord::Migration[8.0]
            def change
              change_table :attachments do |t|
                t.references :record, polymorphic: true, null: false
              end
            end
          end
        RUBY
      ]

      result = build_snapshot(migrations, "2")
      cols = result[:schema_after][:tables]["attachments"][:columns].map { |c| c[:name] }
      expect(cols).to include("record_id")
      expect(cols).to include("record_type")
    end

    it "add timestamps" do
      migrations = [
        migration("1", <<~RUBY),
          class CreateWidgets < ActiveRecord::Migration[8.0]
            def change
              create_table :widgets do |t|
                t.string :name
              end
            end
          end
        RUBY
        migration("2", <<~RUBY)
          class AddTimestampsToWidgets < ActiveRecord::Migration[8.0]
            def change
              change_table :widgets do |t|
                t.timestamps
              end
            end
          end
        RUBY
      ]

      result = build_snapshot(migrations, "2")
      cols = result[:schema_after][:tables]["widgets"][:columns].map { |c| c[:name] }
      expect(cols).to include("created_at")
      expect(cols).to include("updated_at")
    end
  end

  describe "add_column" do
    it "supports parenthesized syntax" do
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

      expect(columns).to include("last_updated_at")
      expect(result[:diff][:modified_tables]["pets_dashboards"][:added_columns]).to eq(["last_updated_at"])
    end

    it "with precision, scale, and comment" do
      migrations = [
        migration("1", <<~RUBY),
          class CreateReadings < ActiveRecord::Migration[8.0]
            def change
              create_table :readings do |t|
                t.string :label
              end
            end
          end
        RUBY
        migration("2", <<~RUBY)
          class AddValueToReadings < ActiveRecord::Migration[8.0]
            def change
              add_column :readings, :value, :decimal, precision: 10, scale: 2, comment: "sensor value"
            end
          end
        RUBY
      ]

      result = build_snapshot(migrations, "2")
      col = result[:schema_after][:tables]["readings"][:columns].find { |c| c[:name] == "value" }
      expect(col[:precision]).to eq(10)
      expect(col[:scale]).to eq(2)
      expect(col[:comment]).to eq("sensor value")
    end

    it "creates table via ensure_table for orphan add_column" do
      result = build_snapshot([
                                migration("1", <<~RUBY)
                                  class AddOrphans < ActiveRecord::Migration[8.0]
                                    def change
                                      add_column :orphans, :name, :string
                                    end
                                  end
                                RUBY
                              ], "1")
      expect(result[:schema_after][:tables].keys).to include("orphans")
    end
  end

  describe "remove_column" do
    it "remove_columns plural" do
      migrations = [
        migration("1", <<~RUBY),
          class CreateReports < ActiveRecord::Migration[8.0]
            def change
              create_table :reports do |t|
                t.string :title
                t.string :body
                t.string :notes
              end
            end
          end
        RUBY
        migration("2", <<~RUBY)
          class CleanupReports < ActiveRecord::Migration[8.0]
            def change
              remove_columns :reports, :body, :notes
            end
          end
        RUBY
      ]

      result = build_snapshot(migrations, "2")
      cols = result[:schema_after][:tables]["reports"][:columns].map { |c| c[:name] }
      expect(cols).to include("title")
      expect(cols).not_to include("body")
      expect(cols).not_to include("notes")
    end
  end

  describe "rename_column" do
    it "updates column name" do
      migrations = [
        migration("1", <<~RUBY),
          class CreateOrders < ActiveRecord::Migration[8.0]
            def change
              create_table :orders do |t|
                t.string :status
              end
            end
          end
        RUBY
        migration("2", <<~RUBY)
          class RenameOrderStatus < ActiveRecord::Migration[8.0]
            def change
              rename_column :orders, :status, :state
            end
          end
        RUBY
      ]

      result = build_snapshot(migrations, "2")
      cols = result[:schema_after][:tables]["orders"][:columns].map { |c| c[:name] }
      expect(cols).to include("state")
      expect(cols).not_to include("status")
    end

    it "on missing table is a no-op" do
      result = build_snapshot([
                                migration("1", <<~RUBY)
                                  class NopeMigration < ActiveRecord::Migration[8.0]
                                    def change
                                      rename_column :ghost, :a, :b
                                    end
                                  end
                                RUBY
                              ], "1")
      expect(result[:schema_after][:tables]).to be_empty
    end
  end

  describe "rename_table" do
    it "moves table under new key" do
      migrations = [
        migration("1", <<~RUBY),
          class CreateInvoices < ActiveRecord::Migration[8.0]
            def change
              create_table :invoices do |t|
                t.string :number
              end
            end
          end
        RUBY
        migration("2", <<~RUBY)
          class RenameInvoicesToBills < ActiveRecord::Migration[8.0]
            def change
              rename_table :invoices, :bills
            end
          end
        RUBY
      ]

      result = build_snapshot(migrations, "2")
      expect(result[:schema_after][:tables]["invoices"]).to be_nil
      cols = result[:schema_after][:tables]["bills"][:columns].map { |c| c[:name] }
      expect(cols).to include("number")
    end
  end

  describe "drop_table" do
    it "removes the table" do
      migrations = [
        migration("1", <<~RUBY),
          class CreateWidgets < ActiveRecord::Migration[8.0]
            def change
              create_table :widgets do |t|
                t.string :name
              end
            end
          end
        RUBY
        migration("2", <<~RUBY)
          class DropWidgets < ActiveRecord::Migration[8.0]
            def change
              drop_table :widgets
            end
          end
        RUBY
      ]

      result = build_snapshot(migrations, "2")
      expect(result[:schema_after][:tables]["widgets"]).to be_nil
      expect(result[:diff][:removed_tables]).to include("widgets")
    end
  end

  describe "change_column" do
    it "updates type" do
      migrations = [
        migration("1", <<~RUBY),
          class CreateDocs < ActiveRecord::Migration[8.0]
            def change
              create_table :docs do |t|
                t.string :body
              end
            end
          end
        RUBY
        migration("2", <<~RUBY)
          class ChangeDocBody < ActiveRecord::Migration[8.0]
            def change
              change_column :docs, :body, :text
            end
          end
        RUBY
      ]

      result = build_snapshot(migrations, "2")
      col = result[:schema_after][:tables]["docs"][:columns].find { |c| c[:name] == "body" }
      expect(col[:type]).to eq("text")
    end
  end

  describe "change_column_default" do
    it "supports :to syntax" do
      migrations = [
        migration("1", <<~RUBY),
          class CreateTasks < ActiveRecord::Migration[8.0]
            def change
              create_table :tasks do |t|
                t.string :state
              end
            end
          end
        RUBY
        migration("2", <<~RUBY)
          class SetDefaultState < ActiveRecord::Migration[8.0]
            def change
              change_column_default :tasks, :state, to: "pending"
            end
          end
        RUBY
      ]

      result = build_snapshot(migrations, "2")
      col = result[:schema_after][:tables]["tasks"][:columns].find { |c| c[:name] == "state" }
      expect(col[:default]).to eq("pending")
    end

    it "supports change_column_default and change_column_null with rename_index" do
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

      expect(status[:default]).to eq("pending")
      expect(status[:null]).to eq(false)
      expect(table[:indexes].first[:name]).to eq("index_invoices_on_state")
    end
  end

  describe "change_column_null" do
    it "without default arg" do
      migrations = [
        migration("1", <<~RUBY),
          class CreateTasks < ActiveRecord::Migration[8.0]
            def change
              create_table :tasks do |t|
                t.string :state
              end
            end
          end
        RUBY
        migration("2", <<~RUBY)
          class MakeStateNotNull < ActiveRecord::Migration[8.0]
            def change
              change_column_null :tasks, :state, false
            end
          end
        RUBY
      ]

      result = build_snapshot(migrations, "2")
      col = result[:schema_after][:tables]["tasks"][:columns].find { |c| c[:name] == "state" }
      expect(col[:null]).to eq(false)
      expect(col[:default]).to be_nil
    end

    it "with default value" do
      migrations = [
        migration("1", <<~RUBY),
          class CreateProducts < ActiveRecord::Migration[8.0]
            def change
              create_table :products do |t|
                t.string :status
              end
            end
          end
        RUBY
        migration("2", <<~RUBY)
          class MakeStatusNotNull < ActiveRecord::Migration[8.0]
            def change
              change_column_null :products, :status, false, "draft"
            end
          end
        RUBY
      ]

      result = build_snapshot(migrations, "2")
      col = result[:schema_after][:tables]["products"][:columns].find { |c| c[:name] == "status" }
      expect(col[:null]).to eq(false)
      expect(col[:default]).to eq("draft")
    end
  end

  describe "change_column_comment" do
    it "updates column comment" do
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
      expect(status[:comment]).to eq("Current workflow state")
    end
  end

  describe "rename_index" do
    it "updates index name" do
      migrations = [
        migration("1", <<~RUBY),
          class CreateEvents < ActiveRecord::Migration[8.0]
            def change
              create_table :events do |t|
                t.string :name
                t.index :name, name: "idx_events_name"
              end
            end
          end
        RUBY
        migration("2", <<~RUBY)
          class RenameEventsIndex < ActiveRecord::Migration[8.0]
            def change
              rename_index :events, :idx_events_name, :idx_events_on_name
            end
          end
        RUBY
      ]

      result = build_snapshot(migrations, "2")
      idx = result[:schema_after][:tables]["events"][:indexes].find { |i| i[:name] == "idx_events_on_name" }
      expect(idx).not_to be_nil
    end
  end

  describe "remove_index" do
    it "standalone by columns" do
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
      expect(result[:schema_after][:tables]["temp_files"][:indexes]).to be_empty
    end

    it "by column option" do
      migrations = [
        migration("1", <<~RUBY),
          class CreateSessions < ActiveRecord::Migration[8.0]
            def change
              create_table :sessions do |t|
                t.string :token
                t.index :token, name: "idx_sessions_token"
              end
            end
          end
        RUBY
        migration("2", <<~RUBY)
          class RemoveSessionsIndex < ActiveRecord::Migration[8.0]
            def change
              remove_index :sessions, column: :token
            end
          end
        RUBY
      ]

      result = build_snapshot(migrations, "2")
      expect(result[:schema_after][:tables]["sessions"][:indexes]).to be_empty
    end
  end

  describe "foreign_key and check_constraint lifecycle" do
    it "add and remove foreign key and check constraint" do
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

      expect(with_constraints[:schema_after][:tables]["invoices"][:foreign_keys].first[:name]).to eq("fk_invoices_accounts")
      expect(with_constraints[:schema_after][:tables]["invoices"][:check_constraints].first[:name]).to eq("amount_positive")
      expect(without_constraints[:schema_after][:tables]["invoices"][:foreign_keys]).to be_empty
      expect(without_constraints[:schema_after][:tables]["invoices"][:check_constraints]).to be_empty
    end

    it "remove_foreign_key by to_table" do
      migrations = [
        migration("1", <<~RUBY),
          class CreateOrders < ActiveRecord::Migration[8.0]
            def change
              create_table :orders do |t|
                t.integer :account_id
              end
            end
          end
        RUBY
        migration("2", <<~RUBY),
          class AddFkToOrders < ActiveRecord::Migration[8.0]
            def change
              add_foreign_key :orders, :accounts
            end
          end
        RUBY
        migration("3", <<~RUBY)
          class RemoveFkFromOrders < ActiveRecord::Migration[8.0]
            def change
              remove_foreign_key :orders, :accounts
            end
          end
        RUBY
      ]

      with_fk = build_snapshot(migrations, "2")
      without_fk = build_snapshot(migrations, "3")
      expect(with_fk[:schema_after][:tables]["orders"][:foreign_keys].size).to eq(1)
      expect(without_fk[:schema_after][:tables]["orders"][:foreign_keys]).to be_empty
    end

    it "remove_check_constraint by expression" do
      migrations = [
        migration("1", <<~RUBY),
          class CreateProducts < ActiveRecord::Migration[8.0]
            def change
              create_table :products do |t|
                t.integer :stock
              end
            end
          end
        RUBY
        migration("2", <<~RUBY),
          class AddCheckToProducts < ActiveRecord::Migration[8.0]
            def change
              add_check_constraint :products, "stock >= 0"
            end
          end
        RUBY
        migration("3", <<~RUBY)
          class RemoveCheckFromProducts < ActiveRecord::Migration[8.0]
            def change
              remove_check_constraint :products, "stock >= 0"
            end
          end
        RUBY
      ]

      with_cc = build_snapshot(migrations, "2")
      without_cc = build_snapshot(migrations, "3")
      expect(with_cc[:schema_after][:tables]["products"][:check_constraints].size).to eq(1)
      expect(without_cc[:schema_after][:tables]["products"][:check_constraints]).to be_empty
    end
  end

  describe "schema_before / schema_after" do
    it "exposes both states" do
      migrations = [
        migration("20250000000001", <<~RUBY),
          class CreateAccounts < ActiveRecord::Migration[8.0]
            def change
              create_table :accounts do |t|
                t.string :name
              end
            end
          end
        RUBY
        migration("20250000000002", <<~RUBY)
          class AddEmailToAccounts < ActiveRecord::Migration[8.0]
            def change
              add_column :accounts, :email, :string
            end
          end
        RUBY
      ]

      result = build_snapshot(migrations, "20250000000002")
      before_columns = result[:schema_before][:tables]["accounts"][:columns].map { |c| c[:name] }
      after_columns = result[:schema_after][:tables]["accounts"][:columns].map { |c| c[:name] }

      expect(before_columns).not_to include("email")
      expect(after_columns).to include("email")
    end
  end

  describe "version boundary" do
    it "respects up_to_version" do
      migrations = [
        migration("1", <<~RUBY),
          class CreateAlpha < ActiveRecord::Migration[8.0]
            def change
              create_table :alpha do |t|
                t.string :x
              end
            end
          end
        RUBY
        migration("2", <<~RUBY)
          class CreateBeta < ActiveRecord::Migration[8.0]
            def change
              create_table :beta do |t|
                t.string :y
              end
            end
          end
        RUBY
      ]

      result = build_snapshot(migrations, "1")
      expect(result[:schema_after][:tables].keys).to include("alpha")
      expect(result[:schema_after][:tables].keys).not_to include("beta")
    end
  end
end
