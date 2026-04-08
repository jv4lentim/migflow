# frozen_string_literal: true

require_relative "migration_dsl_scanner"

module Migflow
  module Services
    class TouchedTablesFromMigration
      SCANNER_FIRST_COLUMN_TABLE_METHODS = %i[
        add_columns
        remove_column
        remove_columns
        rename_columns
        change_columns
        change_column_defaults
        change_column_nulls
        change_column_comments
        add_references
        remove_references
        add_indexes
        remove_indexes
        rename_indexes
        add_foreign_keys
        remove_foreign_keys
        add_check_constraints
        remove_check_constraints
      ].freeze

      def self.call(raw_content:)
        new(raw_content: raw_content).call
      end

      def initialize(raw_content:)
        @raw_content = raw_content.to_s
      end

      def call
        scanner = MigrationDslScanner.new(@raw_content)
        names = base_table_names(scanner) + scanner_method_table_names(scanner)
        names.map(&:to_s).reject(&:empty?).uniq
      end

      private

      def base_table_names(scanner)
        names = []
        names.concat(scanner.create_table_blocks.map(&:first))
        names.concat(scanner.change_table_blocks.map(&:first))
        names.concat(scanner.drop_tables)
        names.concat(scanner.rename_tables.flatten)
        names
      end

      def scanner_method_table_names(scanner)
        SCANNER_FIRST_COLUMN_TABLE_METHODS.flat_map do |method_name|
          scanner.public_send(method_name).map(&:first)
        end
      end
    end
  end
end
