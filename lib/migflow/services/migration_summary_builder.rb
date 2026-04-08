# frozen_string_literal: true

require_relative "migration_dsl_scanner"

module Migflow
  module Services
    class MigrationSummaryBuilder
      def self.call(raw_content:, version:)
        new(raw_content: raw_content, version: version).call
      end

      def initialize(raw_content:, version:)
        @raw_content = raw_content.to_s
        @version = version
      end

      def call
        scanner = MigrationDslScanner.new(@raw_content)

        created_tables = scanner.create_table_blocks.map(&:first)
        return "Created table #{created_tables.join(', ')}" if created_tables.any?

        dropped_tables = scanner.drop_tables
        return "Dropped table #{dropped_tables.join(', ')}" if dropped_tables.any?

        added_details = added_column_details(scanner) + added_reference_details(scanner)
        return "Added #{added_details.join(', ')}" if added_details.any?

        "Migration #{@version}"
      end

      private

      def added_column_details(scanner)
        scanner.add_columns.map { |table, column, *_| "#{column} to #{table}" }
      end

      def added_reference_details(scanner)
        scanner.add_references.map { |table, reference, *_| "#{reference}_id to #{table}" }
      end
    end
  end
end
