# frozen_string_literal: true

require "spec_helper"
require "migflow/services/schema_patch_builder"

RSpec.describe Migflow::Services::SchemaPatchBuilder do
  def table_with_columns(names, indexes: [])
    {
      columns: names.map do |name|
        { name: name, type: "string", null: true, default: nil }
      end,
      indexes: indexes
    }
  end

  def build_patch(from_tables:, to_tables:, changed_tables: nil, include_unchanged: false)
    described_class.call(
      from_tables: from_tables,
      to_tables: to_tables,
      changed_tables: changed_tables,
      include_unchanged: include_unchanged
    )
  end

  describe "collapsed patch" do
    it "keeps real line numbers across multiple hunks" do
      from_tables = {
        "alpha" => table_with_columns(%w[a1 a2 a3]),
        "beta" => table_with_columns(%w[b1 b2 b3 b4 b5 b6])
      }
      to_tables = {
        "alpha" => table_with_columns(%w[a1 a2 a3 a4]),
        "beta" => table_with_columns(%w[b1 b2 b3 b4 b5 b6 b7])
      }

      patch = described_class.call(
        from_tables: from_tables,
        to_tables: to_tables,
        changed_tables: %w[alpha beta],
        include_unchanged: false
      )

      headers = patch.scan(/@@ -(\d+),\d+ \+(\d+),\d+ @@/)
      expect(headers.length).to eq(2)
      expect(headers[0].map(&:to_i)).to eq([1, 1])
      expect(headers[1].map(&:to_i)).to eq([7, 8])
    end

    it "includes table header for changed columns" do
      from_tables = { "indicators" => table_with_columns(%w[c1 c2 c3 c4 c5 c6 c7 c8 c9 c10]) }
      to_tables = { "indicators" => table_with_columns(%w[c1 c2 c3 c4 c5 c6 c7 c8 c9 c10 report_id title]) }

      patch = described_class.call(
        from_tables: from_tables,
        to_tables: to_tables,
        changed_tables: %w[indicators],
        include_unchanged: false
      )

      expect(patch).to include(" create_table \"indicators\" do |t|")
      expect(patch).to include("+  t.string \"report_id\"")
      expect(patch).to include("+  t.string \"title\"")
    end

    it "filters to changed tables only" do
      from_tables = {
        "accounts" => table_with_columns(%w[name]),
        "indicators" => table_with_columns(%w[title old_col])
      }
      to_tables = {
        "accounts" => table_with_columns(%w[name]),
        "indicators" => table_with_columns(%w[title new_col])
      }

      patch = described_class.call(
        from_tables: from_tables,
        to_tables: to_tables,
        changed_tables: %w[indicators],
        include_unchanged: false
      )

      expect(patch).to include(" create_table \"indicators\" do |t|")
      expect(patch).not_to include(" create_table \"accounts\" do |t|")
      expect(patch).to include("-  t.string \"old_col\"")
      expect(patch).to include("+  t.string \"new_col\"")
    end

    it "with nil changed_tables includes all changed sections" do
      from_tables = {
        "accounts" => table_with_columns(%w[name]),
        "indicators" => table_with_columns(%w[title old_col])
      }
      to_tables = {
        "accounts" => table_with_columns(%w[name]),
        "indicators" => table_with_columns(%w[title new_col])
      }

      patch = described_class.call(
        from_tables: from_tables,
        to_tables: to_tables,
        changed_tables: nil,
        include_unchanged: false
      )

      expect(patch).to include(" create_table \"indicators\" do |t|")
      expect(patch).not_to include(" create_table \"accounts\" do |t|")
    end
  end

  describe "full patch" do
    it "includes unchanged tables" do
      from_tables = {
        "accounts" => table_with_columns(%w[name]),
        "indicators" => table_with_columns(%w[title old_col])
      }
      to_tables = {
        "accounts" => table_with_columns(%w[name]),
        "indicators" => table_with_columns(%w[title new_col])
      }

      patch = described_class.call(
        from_tables: from_tables,
        to_tables: to_tables,
        changed_tables: %w[indicators],
        include_unchanged: true
      )

      expect(patch).to include(" create_table \"accounts\" do |t|")
      expect(patch).to include(" create_table \"indicators\" do |t|")
      expect(patch).to include("@@ -1,")
    end
  end

  it "returns empty patch when no diff exists" do
    tables = { "accounts" => table_with_columns(%w[name email]) }
    patch = described_class.call(
      from_tables: tables,
      to_tables: tables,
      changed_tables: %w[accounts],
      include_unchanged: false
    )
    expect(patch).to eq("")
  end

  it "returns empty patch when changed_tables is empty" do
    from_tables = { "indicators" => table_with_columns(%w[title old_col]) }
    to_tables = { "indicators" => table_with_columns(%w[title new_col]) }
    patch = described_class.call(
      from_tables: from_tables,
      to_tables: to_tables,
      changed_tables: [],
      include_unchanged: false
    )
    expect(patch).to eq("")
  end

  it "shows added table" do
    from_tables = {}
    to_tables = {
      "orders" => {
        columns: [{ name: "total", type: "decimal", null: false, default: nil }],
        indexes: []
      }
    }

    patch = build_patch(from_tables: from_tables, to_tables: to_tables)
    expect(patch).to include("+create_table \"orders\" do |t|")
    expect(patch).to include("+  t.decimal \"total\", null: false")
  end

  it "shows removed table" do
    from_tables = {
      "old_logs" => {
        columns: [{ name: "message", type: "text", null: true, default: nil }],
        indexes: []
      }
    }

    patch = build_patch(from_tables: from_tables, to_tables: {})
    expect(patch).to include("-create_table \"old_logs\" do |t|")
    expect(patch).to include("-  t.text \"message\"")
  end

  it "starts first hunk line numbers at one" do
    from_tables = { "alpha" => table_with_columns(%w[a]) }
    to_tables   = { "alpha" => table_with_columns(%w[a b]) }

    patch = build_patch(from_tables: from_tables, to_tables: to_tables, changed_tables: %w[alpha])
    expect(patch).to match(/@@ -1,\d+ \+1,\d+ @@/)
  end

  it "formats index changes" do
    from_tables = {
      "events" => table_with_columns(%w[name],
                                     indexes: [{ name: "index_events_on_name", columns: ["name"], unique: false }])
    }
    to_tables = {
      "events" => table_with_columns(%w[name],
                                     indexes: [{ name: "idx_events_name_unique", columns: ["name"], unique: true }])
    }

    patch = build_patch(from_tables: from_tables, to_tables: to_tables, changed_tables: %w[events])
    expect(patch).to include("-  t.index [\"name\"], name: \"index_events_on_name\"")
    expect(patch).to include("+  t.index [\"name\"], name: \"idx_events_name_unique\", unique: true")
  end

  it "formats index option changes with same name" do
    from_tables = {
      "events" => table_with_columns(%w[name],
                                     indexes: [{ name: "index_events_on_name", columns: ["name"], unique: false }])
    }
    to_tables = {
      "events" => table_with_columns(%w[name],
                                     indexes: [{ name: "index_events_on_name", columns: ["name"], unique: true }])
    }

    patch = build_patch(from_tables: from_tables, to_tables: to_tables, changed_tables: %w[events])
    expect(patch).to include("-  t.index [\"name\"], name: \"index_events_on_name\"")
    expect(patch).to include("+  t.index [\"name\"], name: \"index_events_on_name\", unique: true")
  end

  it "formats column changes with same name" do
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

    patch = build_patch(from_tables: from_tables, to_tables: to_tables, changed_tables: %w[events])
    expect(patch).to include("-  t.string \"title\"")
    expect(patch).to include("+  t.text \"title\", null: false, default: n/a")
  end

  it "uses column join key when index has no name" do
    from_tables = {
      "events" => {
        columns: [{ name: "user_id", type: "integer", null: false, default: nil }],
        indexes: [{ name: nil, columns: ["user_id"], unique: false }]
      }
    }
    to_tables = {
      "events" => {
        columns: [{ name: "user_id", type: "integer", null: false, default: nil }],
        indexes: [{ name: nil, columns: ["user_id"], unique: true }]
      }
    }

    patch = build_patch(from_tables: from_tables, to_tables: to_tables, changed_tables: %w[events])
    expect(patch).to include("-  t.index [\"user_id\"]")
    expect(patch).to include("+  t.index [\"user_id\"], unique: true")
  end

  it "formats column with limit" do
    from_tables = {
      "accounts" => {
        columns: [{ name: "code", type: "string", null: false, default: nil, limit: 10 }],
        indexes: []
      }
    }
    to_tables = {
      "accounts" => {
        columns: [{ name: "code", type: "string", null: false, default: nil, limit: 20 }],
        indexes: []
      }
    }

    patch = build_patch(from_tables: from_tables, to_tables: to_tables, changed_tables: %w[accounts])
    expect(patch).to include("-  t.string \"code\", null: false, limit: 10")
    expect(patch).to include("+  t.string \"code\", null: false, limit: 20")
  end

  it "formats index without name or unique" do
    from_tables = { "sessions" => table_with_columns(%w[token]) }
    to_tables = {
      "sessions" => {
        columns: [{ name: "token", type: "string", null: true, default: nil }],
        indexes: [{ name: nil, columns: ["token"], unique: false }]
      }
    }

    patch = build_patch(from_tables: from_tables, to_tables: to_tables, changed_tables: %w[sessions])
    expect(patch).to include("+  t.index [\"token\"]")
    expect(patch).not_to include("name:")
    expect(patch).not_to include("unique:")
  end

  it "returns empty when both from and to tables are nil" do
    patch = described_class.call(
      from_tables: nil,
      to_tables: nil,
      changed_tables: nil,
      include_unchanged: false
    )
    expect(patch).to eq("")
  end
end
