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

      payload = controller.send(:serialize_detail, migration, snapshot_result, [])

      expect(payload[:version]).to eq("20250000000002")
      expect(payload[:name]).to eq("Add title to events")
      expect(payload[:schema_patch]).to include("+  t.string \"title\"")
      expect(payload[:schema_patch_full]).to include("create_table \"events\" do |t|")
      expect(payload[:schema_after][:tables]).to eq({ "events" => table_with_columns(%w[id title]) })
    end
  end
end
