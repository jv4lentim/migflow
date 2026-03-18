# frozen_string_literal: true

module Migflow
  module Services
    class SnapshotBuilder
      NON_COLUMN_BLOCK_METHODS = %w[index timestamps remove rename change remove_references remove_timestamps remove_index].freeze

      def self.call(migrations:, up_to_version:)
        new(migrations: migrations, up_to_version: up_to_version).build
      end

      def initialize(migrations:, up_to_version:)
        @migrations    = migrations.sort_by { |m| m[:version] }
        @up_to_version = up_to_version
      end

      def build
        before = { tables: {} }
        after  = { tables: {} }

        @migrations.each do |migration|
          break if migration[:version] > @up_to_version
          before = deep_copy(after)
          after  = apply_migration(after, migration[:raw_content])
        end

        { schema_after: after, diff: calculate_diff(before, after) }
      end

      private

      def deep_copy(state)
        Marshal.load(Marshal.dump(state))
      end

      def apply_migration(state, content)
        s = deep_copy(state)
        apply_create_tables(s, content)
        apply_drop_tables(s, content)
        apply_add_columns(s, content)
        apply_remove_columns(s, content)
        apply_add_references(s, content)
        apply_remove_references(s, content)
        apply_rename_columns(s, content)
        apply_rename_tables(s, content)
        apply_change_columns(s, content)
        apply_add_indexes(s, content)
        apply_remove_indexes(s, content)
        apply_change_table_blocks(s, content)
        s
      end

      def apply_create_tables(state, content)
        content.scan(/create_table\s+[:"'](\w+)[:"']?[^\n]*\n(.*?)\n\s*end\b/m) do |table, block|
          state[:tables][table] = { columns: parse_block_columns(block), indexes: [] }
        end
      end

      def apply_drop_tables(state, content)
        content.scan(/drop_table\s+[:"'](\w+)/) { |table,| state[:tables].delete(table) }
      end

      def apply_add_columns(state, content)
        content.scan(/add_column\s+[:"'](\w+)[:"']?,\s*[:"'](\w+)[:"']?,\s*[:"'](\w+)([^\n]*)/) do |table, col, type, opts|
          ensure_table(state, table)
          state[:tables][table][:columns] << build_column(col, type, opts)
        end
      end

      def apply_remove_columns(state, content)
        content.scan(/remove_column\s+[:"'](\w+)[:"']?,\s*[:"'](\w+)/) do |table, col|
          next unless state[:tables][table]
          state[:tables][table][:columns].reject! { |c| c[:name] == col }
        end
      end

      def apply_add_references(state, content)
        content.scan(/add_(?:reference|belongs_to)\s+[:"'](\w+)[:"']?,\s*[:"'](\w+)[:"']?([^\n]*)/) do |table, ref, opts|
          ensure_table(state, table)
          build_reference_columns(ref, opts).each do |column|
            state[:tables][table][:columns] << column
          end
        end
      end

      def apply_remove_references(state, content)
        content.scan(/remove_(?:reference|belongs_to)\s+[:"'](\w+)[:"']?,\s*[:"'](\w+)[:"']?([^\n]*)/) do |table, ref, opts|
          next unless state[:tables][table]
          remove_reference_columns(state[:tables][table], ref, opts)
        end
      end

      def apply_rename_columns(state, content)
        content.scan(/rename_column\s+[:"'](\w+)[:"']?,\s*[:"'](\w+)[:"']?,\s*[:"'](\w+)/) do |table, from, to|
          next unless state[:tables][table]
          col = state[:tables][table][:columns].find { |c| c[:name] == from }
          col[:name] = to if col
        end
      end

      def apply_rename_tables(state, content)
        content.scan(/rename_table\s+[:"'](\w+)[:"']?,\s*[:"'](\w+)/) do |from, to|
          next unless state[:tables][from]
          state[:tables][to] = state[:tables].delete(from)
        end
      end

      def apply_change_columns(state, content)
        content.scan(/change_column\s+[:"'](\w+)[:"']?,\s*[:"'](\w+)[:"']?,\s*[:"'](\w+)/) do |table, col, type|
          next unless state[:tables][table]
          existing = state[:tables][table][:columns].find { |c| c[:name] == col }
          existing[:type] = type if existing
        end
      end

      def apply_add_indexes(state, content)
        content.scan(/add_index\s+[:"'](\w+)[:"']?,\s*(\[.*?\]|[:"']\w+[:"']?)([^\n]*)/) do |table, cols_raw, opts|
          next unless state[:tables][table]
          state[:tables][table][:indexes] << build_index(cols_raw, opts)
        end
      end

      def apply_remove_indexes(state, content)
        content.scan(/remove_index\s+[:"'](\w+)[:"']?,\s*([^\n]+)/) do |table, args|
          next unless state[:tables][table]
          remove_index_from_table(state[:tables][table], args)
        end
      end

      def apply_change_table_blocks(state, content)
        content.scan(/change_table\s+[:"'](\w+)[:"']?[^\n]*\n(.*?)\n\s*end\b/m) do |table, block|
          next unless state[:tables][table]
          add_block_indexes_to_table(state[:tables][table], block)
          add_block_columns_to_table(state[:tables][table], block)
          remove_block_columns_from_table(state[:tables][table], block)
        end
      end

      def add_block_columns_to_table(table_state, block)
        block.scan(/t\.(\w+)\s+[:"'](\w+)[:"']?([^\n]*)/) do |type, name, opts|
          next if NON_COLUMN_BLOCK_METHODS.include?(type)
          if reference_type?(type)
            build_reference_columns(name, opts).each do |column|
              table_state[:columns] << column
            end
            next
          end
          table_state[:columns] << build_column(name, type, opts)
        end
      end

      def remove_block_columns_from_table(table_state, block)
        block.scan(/t\.remove\s+[:"'](\w+)/) do |col,|
          table_state[:columns].reject! { |c| c[:name] == col }
        end
        block.scan(/t\.remove_(?:reference|references|belongs_to)\s+[:"'](\w+)[:"']?([^\n]*)/) do |ref, opts|
          remove_reference_columns(table_state, ref, opts)
        end
      end

      def add_block_indexes_to_table(table_state, block)
        block.scan(/t\.index\s+(\[.*?\]|[:"']\w+[:"']?)([^\n]*)/) do |cols_raw, opts|
          table_state[:indexes] << build_index(cols_raw, opts)
        end
        block.scan(/t\.remove_index\s+([^\n]+)/) do |args,|
          remove_index_from_table(table_state, args)
        end
      end

      def ensure_table(state, table)
        state[:tables][table] ||= { columns: [], indexes: [] }
      end

      def parse_block_columns(block)
        columns = []
        block.scan(/t\.(\w+)\s+[:"'](\w+)[:"']?([^\n]*)/) do |type, name, opts|
          next if %w[index timestamps].include?(type)
          if reference_type?(type)
            build_reference_columns(name, opts).each { |column| columns << column }
            next
          end
          columns << build_column(name, type, opts)
        end
        if block =~ /t\.timestamps/
          columns << { name: "created_at", type: "datetime", null: false, default: nil }
          columns << { name: "updated_at", type: "datetime", null: false, default: nil }
        end
        columns
      end

      def reference_type?(type)
        %w[references belongs_to].include?(type)
      end

      def build_reference_columns(name, opts = "")
        columns = [{
          name: "#{name}_id",
          type: reference_id_type(opts),
          null: reference_null(opts),
          default: nil
        }]
        if opts =~ /polymorphic:\s*true/
          columns << { name: "#{name}_type", type: "string", null: reference_null(opts), default: nil }
        end
        columns
      end

      def remove_reference_columns(table_state, ref, opts = "")
        table_state[:columns].reject! { |c| c[:name] == "#{ref}_id" }
        return unless opts =~ /polymorphic:\s*true/
        table_state[:columns].reject! { |c| c[:name] == "#{ref}_type" }
      end

      def reference_id_type(opts)
        type_match = /type:\s*:?(?:["'])?(\w+)(?:["'])?/.match(opts)
        type_match ? type_match[1] : "bigint"
      end

      def reference_null(opts)
        null_match = /null:\s*(true|false)/.match(opts)
        null_match ? null_match[1] == "true" : true
      end

      def build_column(name, type, opts = "")
        null_match    = /null:\s*(true|false)/.match(opts)
        default_match = /default:\s*([^,\n]+)/.match(opts)
        limit_match   = /limit:\s*(\d+)/.match(opts)
        col = {
          name:    name,
          type:    type,
          null:    null_match ? null_match[1] == "true" : true,
          default: default_match ? default_match[1].strip : nil
        }
        col[:limit] = limit_match[1].to_i if limit_match
        col
      end

      def build_index(cols_raw, opts)
        name_match = /name:\s*"([^"]+)"/.match(opts)
        unique     = /unique:\s*true/.match?(opts)
        cols = if cols_raw.start_with?("[")
                 cols_raw.scan(/[:"'](\w+)[:"']?/).flatten
               else
                 [cols_raw.gsub(/['":,\s]/, "")]
               end
        { name: name_match&.[](1), columns: cols, unique: unique }
      end

      def remove_index_from_table(table_state, args)
        name_match = /name:\s*["']([^"']+)["']/.match(args)
        return table_state[:indexes].reject! { |idx| idx[:name] == name_match[1] } if name_match

        column_match = /column:\s*(\[.*?\]|[:"']\w+[:"']?)/.match(args)
        cols_raw = column_match ? column_match[1] : args
        columns = parse_columns_arg(cols_raw)
        table_state[:indexes].reject! { |idx| idx[:columns] == columns }
      end

      def parse_columns_arg(cols_raw)
        return cols_raw.scan(/[:"'](\w+)[:"']?/).flatten if cols_raw.start_with?("[")
        [cols_raw.gsub(/['":,\s]/, "")]
      end

      def calculate_diff(before, after)
        {
          added_tables:    after[:tables].keys - before[:tables].keys,
          removed_tables:  before[:tables].keys - after[:tables].keys,
          modified_tables: modified_tables_diff(before, after)
        }
      end

      def modified_tables_diff(before, after)
        common = before[:tables].keys & after[:tables].keys
        common.each_with_object({}) do |table, result|
          before_cols = before[:tables][table][:columns].map { |c| c[:name] }
          after_cols  = after[:tables][table][:columns].map { |c| c[:name] }
          added   = after_cols - before_cols
          removed = before_cols - after_cols
          result[table] = { added_columns: added, removed_columns: removed } if added.any? || removed.any?
        end
      end
    end
  end
end
