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
    assert_equal 2, headers.length
    assert_equal [1, 1], headers[0].map(&:to_i)
    assert_equal [7, 8], headers[1].map(&:to_i)
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

  def test_collapsed_patch_filters_to_changed_tables
    from_tables = {
      "accounts" => table_with_columns(%w[name]),
      "indicators" => table_with_columns(%w[title old_col])
    }

    to_tables = {
      "accounts" => table_with_columns(%w[name]),
      "indicators" => table_with_columns(%w[title new_col])
    }

    patch = Migflow::Services::SchemaPatchBuilder.call(
      from_tables: from_tables,
      to_tables: to_tables,
      changed_tables: %w[indicators],
      include_unchanged: false
    )

    assert_includes patch, " create_table \"indicators\" do |t|"
    refute_includes patch, " create_table \"accounts\" do |t|"
    assert_includes patch, "-  t.string \"old_col\""
    assert_includes patch, "+  t.string \"new_col\""
  end

  def test_full_patch_includes_unchanged_tables
    from_tables = {
      "accounts" => table_with_columns(%w[name]),
      "indicators" => table_with_columns(%w[title old_col])
    }

    to_tables = {
      "accounts" => table_with_columns(%w[name]),
      "indicators" => table_with_columns(%w[title new_col])
    }

    patch = Migflow::Services::SchemaPatchBuilder.call(
      from_tables: from_tables,
      to_tables: to_tables,
      changed_tables: %w[indicators],
      include_unchanged: true
    )

    assert_includes patch, " create_table \"accounts\" do |t|"
    assert_includes patch, " create_table \"indicators\" do |t|"
    assert_includes patch, "@@ -1,"
  end

  def test_returns_empty_patch_when_no_diff_exists
    tables = {
      "accounts" => table_with_columns(%w[name email])
    }

    patch = Migflow::Services::SchemaPatchBuilder.call(
      from_tables: tables,
      to_tables: tables,
      changed_tables: %w[accounts],
      include_unchanged: false
    )

    assert_equal "", patch
  end

  def test_returns_empty_patch_when_changed_tables_is_empty
    from_tables = {
      "indicators" => table_with_columns(%w[title old_col])
    }
    to_tables = {
      "indicators" => table_with_columns(%w[title new_col])
    }

    patch = Migflow::Services::SchemaPatchBuilder.call(
      from_tables: from_tables,
      to_tables: to_tables,
      changed_tables: [],
      include_unchanged: false
    )

    assert_equal "", patch
  end

  def test_collapsed_patch_with_nil_changed_tables_includes_all_changed_sections
    from_tables = {
      "accounts" => table_with_columns(%w[name]),
      "indicators" => table_with_columns(%w[title old_col])
    }
    to_tables = {
      "accounts" => table_with_columns(%w[name]),
      "indicators" => table_with_columns(%w[title new_col])
    }

    patch = Migflow::Services::SchemaPatchBuilder.call(
      from_tables: from_tables,
      to_tables: to_tables,
      changed_tables: nil,
      include_unchanged: false
    )

    assert_includes patch, " create_table \"indicators\" do |t|"
    refute_includes patch, " create_table \"accounts\" do |t|"
  end

  def test_formats_index_changes
    from_tables = {
      "events" => table_with_columns(%w[name], indexes: [{ name: "index_events_on_name", columns: ["name"], unique: false }])
    }
    to_tables = {
      "events" => table_with_columns(%w[name], indexes: [{ name: "idx_events_name_unique", columns: ["name"], unique: true }])
    }

    patch = Migflow::Services::SchemaPatchBuilder.call(
      from_tables: from_tables,
      to_tables: to_tables,
      changed_tables: %w[events],
      include_unchanged: false
    )

    assert_includes patch, "-  t.index [\"name\"], name: \"index_events_on_name\""
    assert_includes patch, "+  t.index [\"name\"], name: \"idx_events_name_unique\", unique: true"
  end

  def test_formats_index_option_changes_with_same_name
    from_tables = {
      "events" => table_with_columns(%w[name], indexes: [{ name: "index_events_on_name", columns: ["name"], unique: false }])
    }
    to_tables = {
      "events" => table_with_columns(%w[name], indexes: [{ name: "index_events_on_name", columns: ["name"], unique: true }])
    }

    patch = Migflow::Services::SchemaPatchBuilder.call(
      from_tables: from_tables,
      to_tables: to_tables,
      changed_tables: %w[events],
      include_unchanged: false
    )

    assert_includes patch, "-  t.index [\"name\"], name: \"index_events_on_name\""
    assert_includes patch, "+  t.index [\"name\"], name: \"index_events_on_name\", unique: true"
  end

  def test_formats_column_changes_with_same_name
    from_tables = {
      "events" => {
        columns: [{ name: "title", type: "string", null: true, default: nil }],
        indexes: []
      }
    }
    to_tables = {
      "events" => {
        columns: [{ name: "title", type: "text", null: false, default: "n/a" }],
        indexes: []
      }
    }

    patch = Migflow::Services::SchemaPatchBuilder.call(
      from_tables: from_tables,
      to_tables: to_tables,
      changed_tables: %w[events],
      include_unchanged: false
    )

    assert_includes patch, "-  t.string \"title\""
    assert_includes patch, "+  t.text \"title\", null: false, default: n/a"
  end

  private

  def table_with_columns(names, indexes: [])
    {
      columns: names.map do |name|
        { name: name, type: "string", null: true, default: nil }
      end,
      indexes: indexes
    }
  end
end
