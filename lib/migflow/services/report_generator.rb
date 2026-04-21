# frozen_string_literal: true

require_relative "../parsers/migration_parser"
require_relative "snapshot_builder"
require_relative "scoped_migration_warnings"
require_relative "risk_scorer"

module Migflow
  module Services
    class ReportGenerator
      def call(migrations_path:)
        migrations = Parsers::MigrationParser.call(migrations_path: migrations_path)
        scorer = RiskScorer.new

        analyzed = migrations.map { |m| analyze(m, migrations, scorer) }

        {
          generated_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
          summary: build_summary(analyzed),
          migrations: analyzed
        }
      end

      private

      def analyze(migration, all_migrations, scorer)
        result   = SnapshotBuilder.call(migrations: all_migrations, up_to_version: migration[:version])
        snapshot = snapshot_model(result[:schema_after], migration[:version])
        warnings = ScopedMigrationWarnings.call(snapshot: snapshot, migration: migration, diff: result[:diff])
        risk     = scorer.call(warnings)

        {
          version: migration[:version],
          name: migration[:name],
          risk_score: risk[:score],
          risk_level: risk[:level],
          warnings: warnings.map { |w| serialize_warning(w) }
        }
      end

      def snapshot_model(schema_after, version)
        Models::MigrationSnapshot.new(
          version: version,
          name: "Historical schema",
          tables: schema_after[:tables],
          raw_content: ""
        )
      end

      def serialize_warning(warning)
        {
          rule: warning.rule,
          severity: warning.severity.to_s,
          table: warning.table,
          column: warning.column,
          message: warning.message
        }
      end

      def build_summary(analyzed)
        with_warnings = analyzed.count { |m| m[:warnings].any? }
        with_errors   = analyzed.count { |m| m[:warnings].any? { |w| w[:severity] == "error" } }
        max_score     = analyzed.map { |m| m[:risk_score] }.max || 0
        max_level     = analyzed.max_by { |m| m[:risk_score] }&.fetch(:risk_level) || "safe"

        {
          total_migrations: analyzed.size,
          migrations_with_warnings: with_warnings,
          migrations_with_errors: with_errors,
          highest_risk_score: max_score,
          highest_risk_level: max_level
        }
      end
    end
  end
end
