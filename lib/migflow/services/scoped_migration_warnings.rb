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

      def self.call(snapshot:, migration:)
        new(snapshot: snapshot, migration: migration).call
      end

      def initialize(snapshot:, migration:)
        @snapshot = snapshot
        @migration = migration
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
          touched_tables.include?(warning.table.to_s) || migration_level_warning?(warning)
        end
      end

      private

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
