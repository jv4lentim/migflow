# frozen_string_literal: true

require "test_helper"

class MigrationParserTest < Minitest::Test
  MIGRATIONS_PATH = FIXTURES_PATH.join("migrations")

  def parsed
    @parsed ||= Migrail::Parsers::MigrationParser.call(migrations_path: MIGRATIONS_PATH)
  end

  def test_returns_correct_number_of_migrations
    assert_equal 3, parsed.size
  end

  def test_sorted_by_version_ascending
    versions = parsed.map { |m| m[:version] }
    assert_equal versions.sort, versions
  end

  def test_extracts_version_from_filename
    first = parsed.first
    assert_equal "20240101120000", first[:version]
  end

  def test_humanizes_name
    first = parsed.first
    assert_equal "Create users", first[:name]
  end

  def test_humanizes_name_for_add_migration
    second = parsed[1]
    assert_equal "Add posts", second[:name]
  end

  def test_sets_correct_filename
    first = parsed.first
    assert_equal "20240101120000_create_users.rb", first[:filename]
  end

  def test_reads_raw_content
    first = parsed.first
    assert_includes first[:raw_content], "create_table :users"
  end

  def test_filepath_is_pathname
    first = parsed.first
    assert_instance_of Pathname, first[:filepath]
  end

  def test_ignores_non_rb_files
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "20240101_test.rb"), "# migration")
      File.write(File.join(dir, "README.md"), "# readme")
      result = Migrail::Parsers::MigrationParser.call(migrations_path: dir)
      assert_equal 1, result.size
    end
  end

  def test_returns_empty_for_nonexistent_path
    result = Migrail::Parsers::MigrationParser.call(migrations_path: "/nonexistent/path")
    assert_equal [], result
  end
end
