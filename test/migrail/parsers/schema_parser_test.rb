# frozen_string_literal: true

require "test_helper"

class SchemaParserTest < Minitest::Test
  SCHEMA_PATH = FIXTURES_PATH.join("schemas/schema.rb")

  def parsed
    @parsed ||= Migrail::Parsers::SchemaParser.call(schema_path: SCHEMA_PATH)
  end

  def test_extracts_schema_version
    assert_equal "20240601090000", parsed[:version]
  end

  def test_extracts_all_tables
    assert_includes parsed[:tables].keys, "users"
    assert_includes parsed[:tables].keys, "posts"
    assert_includes parsed[:tables].keys, "tags"
    assert_includes parsed[:tables].keys, "post_tags"
  end

  def test_parses_string_column_with_limit
    email_col = users_column("email")
    assert_equal "string", email_col[:type]
    assert_equal 255,      email_col[:limit]
    assert_equal false,    email_col[:null]
  end

  def test_parses_integer_column_with_default
    role_col = users_column("role")
    assert_equal "integer", role_col[:type]
    assert_equal "0",       role_col[:default]
  end

  def test_parses_column_without_null
    name_col = users_column("name")
    assert_equal false, name_col[:null]
  end

  def test_parses_indexes
    indexes = parsed[:tables]["users"][:indexes]
    assert_equal 1, indexes.size

    idx = indexes.first
    assert_equal ["email"], idx[:columns]
    assert_equal true,      idx[:unique]
    assert_equal "index_users_on_email", idx[:name]
  end

  def test_parses_posts_foreign_key_index
    indexes = parsed[:tables]["posts"][:indexes]
    assert_equal 1, indexes.size
    assert_includes indexes.first[:columns], "user_id"
  end

  def test_parses_columns_count_for_users
    assert_equal 5, parsed[:tables]["users"][:columns].size
  end

  private

  def users_column(name)
    parsed[:tables]["users"][:columns].find { |c| c[:name] == name }
  end
end
