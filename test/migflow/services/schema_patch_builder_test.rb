# frozen_string_literal: true

require "test_helper"
require "migflow/services/schema_patch_builder"

class SchemaPatchBuilderTest < Minitest::Test
  def test_collapsed_patch_keeps_real_line_numbers_across_multiple_hunks
    from_tables = {
      "alpha" => table_with_columns(%w[a1 a2 a3]),
      "beta" => table_with_columns(%w[b1 b2 b3 b4 b5 b6])
    }

    to_tables = {
      "alpha" => table_with_columns(%w[a1 a2 a3 a4]),
      "beta" => table_with_columns(%w[b1 b2 b3 b4 b5 b6 b7])
    }

    patch = Migflow::Services::SchemaPatchBuilder.call(
      from_tables: from_tables,
      to_tables: to_tables,
      changed_tables: %w[alpha beta],
      include_unchanged: false
    )

    headers = patch.scan(/@@ -(\d+),\d+ \+(\d+),\d+ @@/)
    assert_operator headers.length, :>=, 2

    first_old_start = headers[0][0].to_i
    second_old_start = headers[1][0].to_i
    assert_operator second_old_start, :>, first_old_start
  end

  def test_collapsed_patch_includes_table_header_for_changed_columns
    from_tables = {
      "indicators" => table_with_columns(%w[c1 c2 c3 c4 c5 c6 c7 c8 c9 c10])
    }

    to_tables = {
      "indicators" => table_with_columns(%w[c1 c2 c3 c4 c5 c6 c7 c8 c9 c10 report_id title])
    }

    patch = Migflow::Services::SchemaPatchBuilder.call(
      from_tables: from_tables,
      to_tables: to_tables,
      changed_tables: %w[indicators],
      include_unchanged: false
    )

    assert_includes patch, " create_table \"indicators\" do |t|"
    assert_includes patch, "+  t.string \"report_id\""
    assert_includes patch, "+  t.string \"title\""
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
