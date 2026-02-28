# frozen_string_literal: true

require "test_helper"

class AuditAnalyzerTest < Minitest::Test
  def build_snapshot(tables)
    Migrail::Models::MigrationSnapshot.new(
      version:     "20240101",
      name:        "Test snapshot",
      tables:      tables,
      raw_content: ""
    )
  end

  def test_missing_index_rule_detects_unindexed_fk
    tables = {
      "posts" => {
        columns: [
          { name: "id",      type: "bigint",  null: false, default: nil },
          { name: "user_id", type: "integer", null: false, default: nil }
        ],
        indexes: []
      }
    }

    warnings = Migrail::Analyzers::Rules::MissingIndexRule.new.call(tables)
    assert_equal 1, warnings.size
    assert_equal "user_id",             warnings.first.column
    assert_equal "posts",               warnings.first.table
    assert_equal :warning,              warnings.first.severity
    assert_equal "missing_index_rule",  warnings.first.rule
  end

  def test_missing_index_rule_passes_when_indexed
    tables = {
      "posts" => {
        columns: [{ name: "user_id", type: "integer", null: false, default: nil }],
        indexes: [{ name: "idx_posts_user_id", columns: ["user_id"], unique: false }]
      }
    }

    warnings = Migrail::Analyzers::Rules::MissingIndexRule.new.call(tables)
    assert_empty warnings
  end

  def test_string_without_limit_rule_detects_unlimited_string
    tables = {
      "posts" => {
        columns: [{ name: "title", type: "string", null: false, default: nil }],
        indexes: []
      }
    }

    warnings = Migrail::Analyzers::Rules::StringWithoutLimitRule.new.call(tables)
    assert_equal 1, warnings.size
    assert_equal "title", warnings.first.column
    assert_equal :info,   warnings.first.severity
  end

  def test_string_without_limit_rule_passes_when_limit_set
    tables = {
      "users" => {
        columns: [{ name: "email", type: "string", null: false, default: nil, limit: 255 }],
        indexes: []
      }
    }

    warnings = Migrail::Analyzers::Rules::StringWithoutLimitRule.new.call(tables)
    assert_empty warnings
  end

  def test_missing_timestamps_rule_detects_missing_timestamps
    tables = {
      "tags" => {
        columns: [
          { name: "id",   type: "bigint", null: false, default: nil },
          { name: "name", type: "string", null: false, default: nil, limit: 100 }
        ],
        indexes: []
      }
    }

    warnings = Migrail::Analyzers::Rules::MissingTimestampsRule.new.call(tables)
    assert_equal 1, warnings.size
    assert_equal "tags",    warnings.first.table
    assert_equal :warning,  warnings.first.severity
  end

  def test_missing_timestamps_rule_ignores_join_tables
    tables = {
      "post_tags" => {
        columns: [
          { name: "post_id", type: "integer", null: false, default: nil },
          { name: "tag_id",  type: "integer", null: false, default: nil }
        ],
        indexes: []
      }
    }

    warnings = Migrail::Analyzers::Rules::MissingTimestampsRule.new.call(tables)
    assert_empty warnings
  end

  def test_missing_timestamps_rule_passes_when_timestamps_present
    tables = {
      "users" => {
        columns: [
          { name: "id",         type: "bigint",   null: false, default: nil },
          { name: "name",       type: "string",   null: false, default: nil, limit: 100 },
          { name: "created_at", type: "datetime", null: false, default: nil },
          { name: "updated_at", type: "datetime", null: false, default: nil }
        ],
        indexes: []
      }
    }

    warnings = Migrail::Analyzers::Rules::MissingTimestampsRule.new.call(tables)
    assert_empty warnings
  end

  def test_dangerous_migration_rule_detects_remove_column
    migrations = [{ raw_content: "remove_column :users, :email", filename: "20240101_test.rb" }]
    warnings   = Migrail::Analyzers::Rules::DangerousMigrationRule.new.call_with_migrations(migrations)

    assert_equal 1, warnings.size
    assert_equal :error, warnings.first.severity
  end

  def test_dangerous_migration_rule_detects_drop_table
    migrations = [{ raw_content: "drop_table :old_table", filename: "20240101_test.rb" }]
    warnings   = Migrail::Analyzers::Rules::DangerousMigrationRule.new.call_with_migrations(migrations)

    assert_equal 1, warnings.size
    assert_equal :error, warnings.first.severity
  end

  def test_dangerous_migration_rule_detects_rename_column
    migrations = [{ raw_content: "rename_column :posts, :body, :content", filename: "test.rb" }]
    warnings   = Migrail::Analyzers::Rules::DangerousMigrationRule.new.call_with_migrations(migrations)

    assert_equal 1, warnings.size
    assert_equal :error, warnings.first.severity
  end

  def test_dangerous_migration_rule_safe_migration_produces_no_warnings
    migrations = [{ raw_content: "add_column :users, :bio, :text", filename: "test.rb" }]
    warnings   = Migrail::Analyzers::Rules::DangerousMigrationRule.new.call_with_migrations(migrations)

    assert_empty warnings
  end

  def test_missing_foreign_key_rule_detects_fk_column
    tables = {
      "posts" => {
        columns: [{ name: "user_id", type: "integer", null: false, default: nil }],
        indexes: []
      }
    }

    warnings = Migrail::Analyzers::Rules::MissingForeignKeyRule.new.call(tables)
    assert_equal 1, warnings.size
    assert_equal :info, warnings.first.severity
  end
end
