# frozen_string_literal: true

require "spec_helper"
require "action_controller"
require_relative "../../../app/controllers/migflow/application_controller"
require_relative "../../../app/controllers/migflow/api/diff_controller"
require_relative "../../../app/controllers/migflow/api/migrations_controller"

RSpec.describe "API contract" do
  def table_with_columns(names)
    {
      columns: names.map do |name|
        { name: name, type: "string", null: true, default: nil }
      end,
      indexes: []
    }
  end

  describe Migflow::Api::DiffController do
    it "serializes diff including schema patches" do
      controller = described_class.new
      diff = Migflow::Models::SchemaDiff.new(
        from_version: "20250000000001",
        to_version: "20250000000002",
        changes: [
          Migflow::Models::Change.new(type: :added_column, table: "events", detail: "added title (string)")
        ]
      )

      payload = controller.send(
        :serialize_diff,
        {
          diff: diff,
          from_tables: { "events" => table_with_columns(%w[id]) },
          to_tables: { "events" => table_with_columns(%w[id title]) }
        }
      )

      expect(payload[:from_version]).to eq("20250000000001")
      expect(payload[:to_version]).to eq("20250000000002")
      expect(payload[:changes].length).to eq(1)
      expect(payload[:schema_patch]).to include("@@ -")
      expect(payload[:schema_patch]).to include("+  t.string \"title\"")
      expect(payload[:schema_patch_full]).to include("diff --git a/schema.rb b/schema.rb")
    end
  end

  describe Migflow::Api::MigrationsController do
    before { Migflow.configuration.expose_raw_content = true }
    after  { Migflow.configuration.expose_raw_content = true }

    it "serializes migration detail including schema patches" do
      controller = described_class.new
      migration = {
        version: "20250000000002",
        name: "Add title to events",
        raw_content: "add_column :events, :title, :string"
      }
      snapshot_result = {
        schema_before: { tables: { "events" => table_with_columns(%w[id]) } },
        schema_after: { tables: { "events" => table_with_columns(%w[id title]) } },
        diff: {
          added_tables: [],
          removed_tables: [],
          modified_tables: {
            "events" => { added_columns: ["title"], removed_columns: [] }
          }
        }
      }

      risk = { score: 0, level: "safe", factors: [] }
      payload = controller.send(:serialize_detail, migration, snapshot_result, [], risk)

      expect(payload[:version]).to eq("20250000000002")
      expect(payload[:name]).to eq("Add title to events")
      expect(payload[:schema_patch]).to include("+  t.string \"title\"")
      expect(payload[:schema_patch_full]).to include("create_table \"events\" do |t|")
      expect(payload[:schema_after][:tables]).to eq({ "events" => table_with_columns(%w[id title]) })
    end

    it "serializes risk fields into migration detail" do
      controller = described_class.new
      migration = { version: "20250000000002", name: "Drop users", raw_content: "drop_table :users" }
      snapshot_result = {
        schema_before: { tables: {} },
        schema_after: { tables: {} },
        diff: { added_tables: [], removed_tables: ["users"], modified_tables: {} }
      }
      risk = {
        score: 40,
        level: "medium",
        factors: [{ rule: "dangerous_migration_rule", message: "Drops a table", weight: 40 }]
      }

      payload = controller.send(:serialize_detail, migration, snapshot_result, [], risk)

      expect(payload[:risk_score]).to eq(40)
      expect(payload[:risk_level]).to eq("medium")
      expect(payload[:risk_factors]).to eq([{ rule: "dangerous_migration_rule", message: "Drops a table", weight: 40 }])
    end

    it "serializes warnings into migration detail" do
      controller = described_class.new
      migration = { version: "20250000000002", name: "Add col", raw_content: "" }
      snapshot_result = {
        schema_before: { tables: {} },
        schema_after: { tables: {} },
        diff: { added_tables: [], removed_tables: [], modified_tables: {} }
      }
      warning = Migflow::Models::Warning.new(
        rule: "missing_index_rule",
        severity: :warning,
        table: "users",
        column: "account_id",
        message: "Column 'account_id' looks like a foreign key but has no index"
      )

      payload = controller.send(:serialize_detail, migration, snapshot_result, [warning], { score: 15, level: "low", factors: [] })

      expect(payload[:warnings].size).to eq(1)
      expect(payload[:warnings].first).to eq(
        rule: "missing_index_rule",
        severity: :warning,
        table: "users",
        column: "account_id",
        message: "Column 'account_id' looks like a foreign key but has no index"
      )
    end

    context "raw_content exposure" do
      let(:controller) { described_class.new }
      let(:migration)  { { version: "20250000000001", name: "Create users", raw_content: "create_table :users" } }
      let(:empty_snapshot) do
        { schema_before: { tables: {} }, schema_after: { tables: {} },
          diff: { added_tables: [], removed_tables: [], modified_tables: {} } }
      end
      let(:safe_risk) { { score: 0, level: "safe", factors: [] } }

      it "includes raw_content by default (expose_raw_content: true)" do
        payload = controller.send(:serialize_detail, migration, empty_snapshot, [], safe_risk)
        expect(payload[:raw_content]).to eq("create_table :users")
      end

      it "omits raw_content when expose_raw_content is false" do
        Migflow.configuration.expose_raw_content = false
        payload = controller.send(:serialize_detail, migration, empty_snapshot, [], safe_risk)
        expect(payload[:raw_content]).to be_nil
      end
    end
  end
end
