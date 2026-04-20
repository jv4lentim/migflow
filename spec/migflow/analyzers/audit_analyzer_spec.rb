# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Analyzer Rules" do
  describe Migflow::Analyzers::Rules::MissingIndexRule do
    it "detects unindexed foreign key column" do
      tables = {
        "posts" => {
          columns: [
            { name: "id",      type: "bigint",  null: false, default: nil },
            { name: "user_id", type: "integer", null: false, default: nil }
          ],
          indexes: []
        }
      }

      warnings = described_class.new.call(tables)
      expect(warnings.size).to eq(1)
      expect(warnings.first.column).to eq("user_id")
      expect(warnings.first.table).to eq("posts")
      expect(warnings.first.severity).to eq(:warning)
      expect(warnings.first.rule).to eq("missing_index_rule")
    end

    it "passes when foreign key column is indexed" do
      tables = {
        "posts" => {
          columns: [{ name: "user_id", type: "integer", null: false, default: nil }],
          indexes: [{ name: "idx_posts_user_id", columns: ["user_id"], unique: false }]
        }
      }

      expect(described_class.new.call(tables)).to be_empty
    end

    it "passes when foreign key column is covered by a composite index" do
      tables = {
        "posts" => {
          columns: [{ name: "user_id", type: "integer", null: false, default: nil }],
          indexes: [{ name: "idx_posts_user_status", columns: %w[user_id status], unique: false }]
        }
      }

      expect(described_class.new.call(tables)).to be_empty
    end
  end

  describe Migflow::Analyzers::Rules::StringWithoutLimitRule do
    it "detects string column without limit" do
      tables = {
        "posts" => {
          columns: [{ name: "title", type: "string", null: false, default: nil }],
          indexes: []
        }
      }

      warnings = described_class.new.call(tables)
      expect(warnings.size).to eq(1)
      expect(warnings.first.column).to eq("title")
      expect(warnings.first.severity).to eq(:info)
    end

    it "passes when limit is set" do
      tables = {
        "users" => {
          columns: [{ name: "email", type: "string", null: false, default: nil, limit: 255 }],
          indexes: []
        }
      }

      expect(described_class.new.call(tables)).to be_empty
    end
  end

  describe Migflow::Analyzers::Rules::MissingTimestampsRule do
    it "detects missing timestamps" do
      tables = {
        "tags" => {
          columns: [
            { name: "id",   type: "bigint", null: false, default: nil },
            { name: "name", type: "string", null: false, default: nil, limit: 100 }
          ],
          indexes: []
        }
      }

      warnings = described_class.new.call(tables)
      expect(warnings.size).to eq(1)
      expect(warnings.first.table).to eq("tags")
      expect(warnings.first.severity).to eq(:warning)
    end

    it "warns when only created_at is present" do
      tables = {
        "posts" => {
          columns: [
            { name: "id",         type: "bigint",   null: false, default: nil },
            { name: "created_at", type: "datetime", null: false, default: nil }
          ],
          indexes: []
        }
      }

      expect(described_class.new.call(tables)).not_to be_empty
    end

    it "warns when only updated_at is present" do
      tables = {
        "posts" => {
          columns: [
            { name: "id",         type: "bigint",   null: false, default: nil },
            { name: "updated_at", type: "datetime", null: false, default: nil }
          ],
          indexes: []
        }
      }

      expect(described_class.new.call(tables)).not_to be_empty
    end

    it "ignores join tables" do
      tables = {
        "post_tags" => {
          columns: [
            { name: "post_id", type: "integer", null: false, default: nil },
            { name: "tag_id",  type: "integer", null: false, default: nil }
          ],
          indexes: []
        }
      }

      expect(described_class.new.call(tables)).to be_empty
    end

    it "does not ignore a 3-column table that has a non-_id column" do
      tables = {
        "memberships" => {
          columns: [
            { name: "user_id",  type: "integer", null: false, default: nil },
            { name: "group_id", type: "integer", null: false, default: nil },
            { name: "role",     type: "string",  null: false, default: nil }
          ],
          indexes: []
        }
      }

      expect(described_class.new.call(tables)).not_to be_empty
    end

    it "ignores a 3-column join table where all columns end in _id" do
      tables = {
        "a_b_c" => {
          columns: [
            { name: "a_id", type: "integer", null: false, default: nil },
            { name: "b_id", type: "integer", null: false, default: nil },
            { name: "c_id", type: "integer", null: false, default: nil }
          ],
          indexes: []
        }
      }

      expect(described_class.new.call(tables)).to be_empty
    end

    it "passes when timestamps are present" do
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

      expect(described_class.new.call(tables)).to be_empty
    end
  end

  describe Migflow::Analyzers::Rules::DangerousMigrationRule do
    it "detects remove_column" do
      migrations = [{ raw_content: "remove_column :users, :email", filename: "20240101_test.rb" }]
      warnings = described_class.new.call_with_migrations(migrations)

      expect(warnings.size).to eq(1)
      expect(warnings.first.severity).to eq(:error)
    end

    it "detects drop_table" do
      migrations = [{ raw_content: "drop_table :old_table", filename: "20240101_test.rb" }]
      warnings = described_class.new.call_with_migrations(migrations)

      expect(warnings.size).to eq(1)
      expect(warnings.first.severity).to eq(:error)
    end

    it "detects rename_column" do
      migrations = [{ raw_content: "rename_column :posts, :body, :content", filename: "test.rb" }]
      warnings = described_class.new.call_with_migrations(migrations)

      expect(warnings.size).to eq(1)
      expect(warnings.first.severity).to eq(:error)
    end

    it "produces no warnings for safe migrations" do
      migrations = [{ raw_content: "add_column :users, :bio, :text", filename: "test.rb" }]
      expect(described_class.new.call_with_migrations(migrations)).to be_empty
    end

    it "generates one warning per dangerous operation when multiple are present" do
      migrations = [{
        raw_content: "remove_column :users, :email\ndrop_table :old_sessions",
        filename: "20240101_test.rb"
      }]
      warnings = described_class.new.call_with_migrations(migrations)

      rules = warnings.map(&:rule)
      expect(rules.count("dangerous_migration_rule")).to eq(2)
    end
  end

  describe Migflow::Analyzers::Rules::MissingForeignKeyRule do
    it "detects foreign key column without constraint" do
      tables = {
        "posts" => {
          columns: [{ name: "user_id", type: "integer", null: false, default: nil }],
          indexes: []
        }
      }

      warnings = described_class.new.call(tables)
      expect(warnings.size).to eq(1)
      expect(warnings.first.severity).to eq(:info)
    end

    it "passes when no foreign key columns present" do
      tables = {
        "tags" => {
          columns: [{ name: "name", type: "string", null: false, default: nil }],
          indexes: []
        }
      }

      expect(described_class.new.call(tables)).to be_empty
    end
  end

  describe Migflow::Analyzers::Rules::NullColumnWithoutDefaultRule do
    it "detects risky add_column with null: false and no default" do
      migrations = [{ raw_content: "add_column :users, :score, :integer, null: false", filename: "t.rb" }]
      warnings = described_class.new.call_with_migrations(migrations)

      expect(warnings.size).to eq(1)
      expect(warnings.first.severity).to eq(:error)
      expect(warnings.first.column).to eq("score")
    end

    it "passes when column is nullable" do
      migrations = [{ raw_content: "add_column :users, :bio, :text, null: true", filename: "t.rb" }]
      expect(described_class.new.call_with_migrations(migrations)).to be_empty
    end

    it "passes when column has a default" do
      migrations = [{ raw_content: "add_column :users, :score, :integer, null: false, default: 0", filename: "t.rb" }]
      expect(described_class.new.call_with_migrations(migrations)).to be_empty
    end
  end
end
