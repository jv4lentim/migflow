# frozen_string_literal: true

require_relative "../analyzers/audit_analyzer"
require_relative "../models/warning"
require_relative "touched_tables_from_migration"

module Migflow
  module Services
    class ScopedMigrationWarnings
      MIGRATION_LEVEL_RULES = %w[
        dangerous_migration_rule
        null_column_without_default_rule
      ].freeze

      NOOP_INFO_RULE = "no_schema_change_migration_rule"

      def self.call(snapshot:, migration:, diff: nil)
        new(snapshot: snapshot, migration: migration, diff: diff).call
      end

      def initialize(snapshot:, migration:, diff: nil)
        @snapshot  = snapshot
        @migration = migration
        @diff      = diff
      end

      def call
        warnings = Analyzers::AuditAnalyzer.call(snapshot: @snapshot, raw_migrations: [@migration])
        touched_tables = TouchedTablesFromMigration.call(raw_content: @migration[:raw_content])

        if touched_tables.empty?
          result = warnings.select { migration_level_warning?(_1) }
          result << noop_migration_warning if noop_migration?(@migration[:raw_content].to_s)
          return result
        end

        warnings.select do |warning|
          migration_level_warning?(warning) || relevant_schema_warning?(warning, touched_tables)
        end
      end

      private

      def relevant_schema_warning?(warning, touched_tables)
        table = warning.table.to_s
        return false unless touched_tables.include?(table)
        return true if @diff.nil?

        change_scoped_relevant?(warning, table)
      end

      def change_scoped_relevant?(warning, table)
        return true if added_table?(table)

        col = warning.column.to_s
        return false if col.empty?

        added_columns_for(table).include?(col)
      end

      def added_table?(table)
        (@diff[:added_tables] || []).map(&:to_s).include?(table)
      end

      def added_columns_for(table)
        entry = (@diff[:modified_tables] || {})[table] || {}
        (entry[:added_columns] || []).map(&:to_s)
      end

      def migration_level_warning?(warning)
        MIGRATION_LEVEL_RULES.include?(warning.rule.to_s)
      end

      def noop_migration?(content)
        return false if content.match?(/\bexecute\b/)
        return false if content.match?(/\benable_extension\b/)
        return false if content.match?(/\bcreate_extension\b/)

        true
      end

      def noop_migration_warning
        Models::Warning.new(
          rule: NOOP_INFO_RULE,
          severity: :info,
          table: "_",
          column: nil,
          message: "No schema operations detected (empty migration or DSL not recognized by Migflow)."
        )
      end
    end
  end
end
