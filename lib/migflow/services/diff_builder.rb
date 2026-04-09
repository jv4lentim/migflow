# frozen_string_literal: true

module Migflow
  module Services
    class DiffBuilder
      def self.call(from_tables:, to_tables:, from_version:, to_version:)
        new(from_tables: from_tables, to_tables: to_tables,
            from_version: from_version, to_version: to_version).build
      end

      def initialize(from_tables:, to_tables:, from_version:, to_version:)
        @from_tables  = from_tables
        @to_tables    = to_tables
        @from_version = from_version
        @to_version   = to_version
      end

      def build
        Models::SchemaDiff.new(
          from_version: @from_version,
          to_version: @to_version,
          changes: table_changes + column_changes + index_changes
        )
      end

      private

      def table_changes
        added   = (@to_tables.keys - @from_tables.keys).map { |t| change(:added_table, t, "added table #{t}") }
        removed = (@from_tables.keys - @to_tables.keys).map { |t| change(:removed_table, t, "removed table #{t}") }
        added + removed
      end

      def column_changes
        common_tables.flat_map do |table|
          from_cols = column_map(@from_tables[table])
          to_cols   = column_map(@to_tables[table])

          added = (to_cols.keys - from_cols.keys).map do |c|
            change(:added_column, table, "added #{c} (#{to_cols[c][:type]})")
          end
          removed = (from_cols.keys - to_cols.keys).map do |c|
            change(:removed_column, table, "removed #{c} (#{from_cols[c][:type]})")
          end
          added + removed
        end
      end

      def index_changes
        common_tables.flat_map do |table|
          from_idxs = index_map(@from_tables[table])
          to_idxs   = index_map(@to_tables[table])

          added   = (to_idxs.keys - from_idxs.keys).map { |i| change(:added_index, table, "added index #{i}") }
          removed = (from_idxs.keys - to_idxs.keys).map { |i| change(:removed_index, table, "removed index #{i}") }
          added + removed
        end
      end

      def common_tables
        @from_tables.keys & @to_tables.keys
      end

      def column_map(table)
        table[:columns].index_by { |c| c[:name] }
      end

      def index_map(table)
        table[:indexes].index_by { |i| i[:name] || i[:columns].join("_") }
      end

      def change(type, table, detail)
        Models::Change.new(type: type, table: table, detail: detail)
      end
    end
  end
end
