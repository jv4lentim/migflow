# frozen_string_literal: true

require "spec_helper"

RSpec.describe Migflow::Parsers::SchemaParser do
  let(:schema_path) { FIXTURES_PATH.join("schemas/schema.rb") }
  let(:parsed) { described_class.call(schema_path: schema_path) }

  def users_column(name)
    parsed[:tables]["users"][:columns].find { |c| c[:name] == name }
  end

  def parse_inline(content)
    require "tempfile"
    Tempfile.create(["schema", ".rb"]) do |f|
      f.write(content)
      f.flush
      described_class.call(schema_path: f.path)
    end
  end

  it "extracts schema version" do
    expect(parsed[:version]).to eq("20240601090000")
  end

  it "extracts all tables" do
    expect(parsed[:tables].keys).to include("users", "posts", "tags", "post_tags")
  end

  it "parses string column with limit" do
    email_col = users_column("email")
    expect(email_col[:type]).to eq("string")
    expect(email_col[:limit]).to eq(255)
    expect(email_col[:null]).to eq(false)
  end

  it "parses integer column with default" do
    role_col = users_column("role")
    expect(role_col[:type]).to eq("integer")
    expect(role_col[:default]).to eq("0")
  end

  it "parses column without null" do
    expect(users_column("name")[:null]).to eq(false)
  end

  it "parses indexes" do
    indexes = parsed[:tables]["users"][:indexes]
    expect(indexes.size).to eq(1)

    idx = indexes.first
    expect(idx[:columns]).to eq(["email"])
    expect(idx[:unique]).to eq(true)
    expect(idx[:name]).to eq("index_users_on_email")
  end

  it "parses posts foreign key index" do
    indexes = parsed[:tables]["posts"][:indexes]
    expect(indexes.size).to eq(1)
    expect(indexes.first[:columns]).to include("user_id")
  end

  it "parses columns count for users" do
    expect(parsed[:tables]["users"][:columns].size).to eq(5)
  end

  it "extracts nil version when missing" do
    result = parse_inline(<<~RUBY)
      ActiveRecord::Schema.define do
        create_table "things" do |t|
          t.string "name"
        end
      end
    RUBY
    expect(result[:version]).to be_nil
  end

  it "parses version with bracket syntax" do
    result = parse_inline(<<~RUBY)
      ActiveRecord::Schema[7.1].define(version: 2024_01_01_000000) do
        create_table "things" do |t|
          t.string "name"
        end
      end
    RUBY
    expect(result[:version]).to eq("20240101000000")
  end

  it "parses index without name" do
    result = parse_inline(<<~RUBY)
      ActiveRecord::Schema[7.1].define(version: 20240101000000) do
        create_table "items" do |t|
          t.string "code"
        end
        add_index "items", ["code"]
      end
    RUBY
    idx = result[:tables]["items"][:indexes].first
    expect(idx[:name]).to be_nil
    expect(idx[:columns]).to eq(["code"])
  end

  it "parses single column index as non-array" do
    result = parse_inline(<<~RUBY)
      ActiveRecord::Schema[7.1].define(version: 20240101000000) do
        create_table "items" do |t|
          t.string "code"
        end
        add_index "items", "code", name: "idx_items_code"
      end
    RUBY
    idx = result[:tables]["items"][:indexes].first
    expect(idx[:columns]).to eq(["code"])
    expect(idx[:name]).to eq("idx_items_code")
  end

  it "has empty indexes array for table with no indexes" do
    result = parse_inline(<<~RUBY)
      ActiveRecord::Schema[7.1].define(version: 20240101000000) do
        create_table "things" do |t|
          t.string "name"
        end
      end
    RUBY
    expect(result[:tables]["things"][:indexes]).to eq([])
  end

  it "returns no tables for empty schema" do
    result = parse_inline(<<~RUBY)
      ActiveRecord::Schema[7.1].define(version: 20240101000000) do
      end
    RUBY
    expect(result[:tables]).to eq({})
  end
end
