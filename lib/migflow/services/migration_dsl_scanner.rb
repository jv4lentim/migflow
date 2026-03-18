# frozen_string_literal: true

module Migflow
  module Services
    class MigrationDslScanner
      BLOCK_NON_COLUMNS = %w[
        column index timestamps remove remove_columns rename change
        change_default change_null remove_references remove_timestamps
        remove_index rename_index check_constraint remove_check_constraint
      ].freeze

      def initialize(content)
        @content = content
      end

      def create_table_blocks
        @content.scan(/create_table\s+[:"'](\w+)[:"']?[^\n]*\n(.*?)\n\s*end\b/m)
      end

      def change_table_blocks
        @content.scan(/change_table\s+[:"'](\w+)[:"']?[^\n]*\n(.*?)\n\s*end\b/m)
      end

      def drop_tables
        @content.scan(/drop_table\s+[:"'](\w+)/).flatten
      end

      def add_columns
        @content.scan(/add_column\s+[:"'](\w+)[:"']?,\s*[:"'](\w+)[:"']?,\s*[:"'](\w+)([^\n]*)/)
      end

      def remove_column
        @content.scan(/remove_column\s+[:"'](\w+)[:"']?,\s*[:"'](\w+)/)
      end

      def remove_columns
        @content.scan(/remove_columns\s+[:"'](\w+)[:"']?,\s*([^\n]+)/)
      end

      def add_references
        @content.scan(/add_(?:reference|belongs_to)\s+[:"'](\w+)[:"']?,\s*[:"'](\w+)[:"']?([^\n]*)/)
      end

      def remove_references
        @content.scan(/remove_(?:reference|references|belongs_to)\s+[:"'](\w+)[:"']?,\s*[:"'](\w+)[:"']?([^\n]*)/)
      end

      def rename_columns
        @content.scan(/rename_column\s+[:"'](\w+)[:"']?,\s*[:"'](\w+)[:"']?,\s*[:"'](\w+)/)
      end

      def rename_tables
        @content.scan(/rename_table\s+[:"'](\w+)[:"']?,\s*[:"'](\w+)/)
      end

      def rename_indexes
        @content.scan(/rename_index\s+[:"'](\w+)[:"']?,\s*([:"']\w+[:"']?),\s*([:"']\w+[:"']?)/)
      end

      def change_columns
        @content.scan(/change_column\s+[:"'](\w+)[:"']?,\s*[:"'](\w+)[:"']?,\s*[:"'](\w+)/)
      end

      def change_column_defaults
        @content.scan(/change_column_default\s+[:"'](\w+)[:"']?,\s*[:"'](\w+)[:"']?,\s*([^\n]+)/)
      end

      def change_column_nulls
        @content.scan(/change_column_null\s+[:"'](\w+)[:"']?,\s*[:"'](\w+)[:"']?,\s*(true|false)(?:,\s*([^\n]+))?/)
      end

      def change_column_comments
        @content.scan(/change_column_comment\s+[:"'](\w+)[:"']?,\s*[:"'](\w+)[:"']?,\s*([^\n]+)/)
      end

      def add_indexes
        @content.scan(/add_index\s+[:"'](\w+)[:"']?,\s*(\[.*?\]|[:"']\w+[:"']?)([^\n]*)/)
      end

      def remove_indexes
        @content.scan(/remove_index\s+[:"'](\w+)[:"']?,\s*([^\n]+)/)
      end

      def add_foreign_keys
        @content.scan(/add_foreign_key\s+[:"'](\w+)[:"']?,\s*[:"'](\w+)[:"']?([^\n]*)/)
      end

      def remove_foreign_keys
        @content.scan(/remove_foreign_key\s+[:"'](\w+)[:"']?,\s*([^\n]+)/)
      end

      def add_check_constraints
        @content.scan(/add_check_constraint\s+[:"'](\w+)[:"']?,\s*["'](.+?)["']([^\n]*)/)
      end

      def remove_check_constraints
        @content.scan(/remove_check_constraint\s+[:"'](\w+)[:"']?,\s*([^\n]+)/)
      end

      def block_column_definitions(block)
        definitions = []

        block.scan(/t\.column\s+[:"'](\w+)[:"']?,\s*:?(?:["'])?(\w+)(?:["'])?([^\n]*)/) do |name, type, opts|
          definitions << [:column, name, type, opts]
        end

        block.scan(/t\.(\w+)\s+[:"'](\w+)[:"']?([^\n]*)/) do |type, name, opts|
          next if BLOCK_NON_COLUMNS.include?(type)
          definitions << [type, name, opts]
        end

        definitions
      end

      def block_has_timestamps?(block)
        block.match?(/t\.timestamps/)
      end

      def block_add_indexes(block)
        block.scan(/t\.index\s+(\[.*?\]|[:"']\w+[:"']?)([^\n]*)/)
      end

      def block_remove_indexes(block)
        block.scan(/t\.remove_index\s+([^\n]+)/).flatten
      end

      def block_remove_columns(block)
        block.scan(/t\.remove\s+[:"'](\w+)/).flatten
      end

      def block_remove_columns_plural(block)
        block.scan(/t\.remove_columns\s+([^\n]+)/).flatten
      end

      def block_remove_references(block)
        block.scan(/t\.remove_(?:reference|references|belongs_to)\s+[:"'](\w+)[:"']?([^\n]*)/)
      end

      def block_change_defaults(block)
        block.scan(/t\.change_default\s+[:"'](\w+)[:"']?,\s*([^\n]+)/)
      end

      def block_change_nulls(block)
        block.scan(/t\.change_null\s+[:"'](\w+)[:"']?,\s*(true|false)(?:,\s*([^\n]+))?/)
      end

      def block_rename_indexes(block)
        block.scan(/t\.rename_index\s+([:"']\w+[:"']?),\s*([:"']\w+[:"']?)/)
      end

      def block_add_check_constraints(block)
        block.scan(/t\.check_constraint\s+["'](.+?)["']([^\n]*)/)
      end

      def block_remove_check_constraints(block)
        block.scan(/t\.remove_check_constraint\s+([^\n]+)/).flatten
      end
    end
  end
end
