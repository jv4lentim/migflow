# frozen_string_literal: true

require "test_helper"
require "migflow/services/snapshot_builder"

class SnapshotBuilderTest < Minitest::Test
  def test_create_table_references_builds_fk_column
    result = build_snapshot([
      migration("20250000000001", <<~RUBY),
        class CreateAlbums < ActiveRecord::Migration[8.0]
          def change
            create_table :albums do |t|
              t.string :name
            end
          end
        end
      RUBY
      migration("20250000000002", <<~RUBY)
        class CreateTempFiles < ActiveRecord::Migration[8.0]
          def change
            create_table :temp_files do |t|
              t.references :album, null: false, foreign_key: true
            end
          end
        end
      RUBY
    ], "20250000000002")

    columns = result[:schema_after][:tables]["temp_files"][:columns].map { |c| c[:name] }
    assert_includes columns, "album_id"
    refute_includes columns, "album"
    assert_includes result[:diff][:added_tables], "temp_files"
  end

  def test_add_and_remove_reference_methods_are_supported
    migrations = [
      migration("20250000000001", <<~RUBY),
        class CreateTempFiles < ActiveRecord::Migration[8.0]
          def change
            create_table :temp_files do |t|
              t.string :name
            end
          end
        end
      RUBY
      migration("20250000000002", <<~RUBY),
        class AddAlbumToTempFiles < ActiveRecord::Migration[8.0]
          def change
            add_belongs_to :temp_files, :album, null: false
          end
        end
      RUBY
      migration("20250000000003", <<~RUBY)
        class RemoveAlbumFromTempFiles < ActiveRecord::Migration[8.0]
          def change
            remove_reference :temp_files, :album
          end
        end
      RUBY
    ]

    added = build_snapshot(migrations, "20250000000002")
    removed = build_snapshot(migrations, "20250000000003")

    added_columns = added[:schema_after][:tables]["temp_files"][:columns].map { |c| c[:name] }
    removed_columns = removed[:schema_after][:tables]["temp_files"][:columns].map { |c| c[:name] }

    assert_includes added_columns, "album_id"
    refute_includes removed_columns, "album_id"
  end

  def test_change_table_references_and_indexes
    migrations = [
      migration("20250000000001", <<~RUBY),
        class CreateTempFiles < ActiveRecord::Migration[8.0]
          def change
            create_table :temp_files do |t|
              t.string :name
            end
          end
        end
      RUBY
      migration("20250000000002", <<~RUBY),
        class UpdateTempFiles < ActiveRecord::Migration[8.0]
          def change
            change_table :temp_files do |t|
              t.references :album, null: false
              t.index :album_id, name: "index_temp_files_on_album_id"
            end
          end
        end
      RUBY
      migration("20250000000003", <<~RUBY)
        class CleanupTempFiles < ActiveRecord::Migration[8.0]
          def change
            change_table :temp_files do |t|
              t.remove_references :album
              t.remove_index name: "index_temp_files_on_album_id"
            end
          end
        end
      RUBY
    ]

    added = build_snapshot(migrations, "20250000000002")
    removed = build_snapshot(migrations, "20250000000003")

    added_columns = added[:schema_after][:tables]["temp_files"][:columns].map { |c| c[:name] }
    added_indexes = added[:schema_after][:tables]["temp_files"][:indexes]
    removed_columns = removed[:schema_after][:tables]["temp_files"][:columns].map { |c| c[:name] }
    removed_indexes = removed[:schema_after][:tables]["temp_files"][:indexes]

    assert_includes added_columns, "album_id"
    assert_equal "index_temp_files_on_album_id", added_indexes.first[:name]
    refute_includes removed_columns, "album_id"
    assert_empty removed_indexes
  end

  def test_remove_index_standalone_by_columns
    migrations = [
      migration("20250000000001", <<~RUBY),
        class CreateTempFiles < ActiveRecord::Migration[8.0]
          def change
            create_table :temp_files do |t|
              t.string :name
              t.timestamps
            end
            add_index :temp_files, [:name, :created_at], name: "index_temp_files_on_name_and_created_at"
          end
        end
      RUBY
      migration("20250000000002", <<~RUBY)
        class RemoveTempFilesIndex < ActiveRecord::Migration[8.0]
          def change
            remove_index :temp_files, [:name, :created_at]
          end
        end
      RUBY
    ]

    result = build_snapshot(migrations, "20250000000002")
    assert_empty result[:schema_after][:tables]["temp_files"][:indexes]
  end

  private

  def migration(version, raw_content)
    { version: version, raw_content: raw_content }
  end

  def build_snapshot(migrations, up_to_version)
    Migflow::Services::SnapshotBuilder.call(migrations: migrations, up_to_version: up_to_version)
  end
end
