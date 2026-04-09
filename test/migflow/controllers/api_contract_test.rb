# frozen_string_literal: true

require "test_helper"
require "action_controller"
require_relative "../../../app/controllers/migflow/application_controller"
require_relative "../../../app/controllers/migflow/api/diff_controller"
require_relative "../../../app/controllers/migflow/api/migrations_controller"

class ApiContractTest < Minitest::Test
  def test_diff_serialization_includes_schema_patches
    controller = Migflow::Api::DiffController.new
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
        from_tables: {
          "events" => table_with_columns(%w[id])
        },
        to_tables: {
          "events" => table_with_columns(%w[id title])
        }
      }
    )

    assert_equal "20250000000001", payload[:from_version]
    assert_equal "20250000000002", payload[:to_version]
    assert_equal 1, payload[:changes].length
    assert payload[:schema_patch].include?("@@ -")
    assert payload[:schema_patch].include?("+  t.string \"title\"")
    assert payload[:schema_patch_full].include?("diff --git a/schema.rb b/schema.rb")
  end

  def test_migration_detail_serialization_includes_schema_patches
    controller = Migflow::Api::MigrationsController.new
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

    assert_equal "20250000000002", payload[:version]
    assert_equal "Add title to events", payload[:name]
    assert payload[:schema_patch].include?("+  t.string \"title\"")
    assert payload[:schema_patch_full].include?("create_table \"events\" do |t|")
    assert_equal({ "events" => table_with_columns(%w[id title]) }, payload[:schema_after][:tables])
  end

  private

  def table_with_columns(names)
    {
      columns: names.map do |name|
        { name: name, type: "string", null: true, default: nil }
      end,
      indexes: []
    }
  end
end
