# frozen_string_literal: true

module Migflow
  module Api
    class MigrationsController < ApplicationController
      def index
        migrations = Parsers::MigrationParser.call(migrations_path: migrations_path)
        render_json(migrations: migrations.map { |m| serialize_summary(m, migrations) })
      end

      def show
        migrations = Parsers::MigrationParser.call(migrations_path: migrations_path)
        migration  = migrations.find { |m| m[:version] == params[:id] }

        return render_error("Migration not found", status: :not_found) unless migration

        result   = Services::SnapshotBuilder.call(migrations: migrations, up_to_version: params[:id])
        snapshot = snapshot_model_from(result[:schema_after], migration[:version])
        warnings = Services::ScopedMigrationWarnings.call(snapshot: snapshot, migration: migration, diff: result[:diff])
        risk     = Services::RiskScorer.new.call(warnings)

        render_json(migration: serialize_detail(migration, result, warnings, risk))
      end

      private

      def snapshot_model_from(schema_after, version)
        Models::MigrationSnapshot.new(
          version: version,
          name: "Historical schema",
          tables: schema_after[:tables],
          raw_content: ""
        )
      end

      def serialize_summary(migration, all_migrations)
        risk = compute_risk(migration, all_migrations)
        {
          version: migration[:version],
          name: migration[:name],
          filename: migration[:filename],
          summary: Services::MigrationSummaryBuilder.call(
            raw_content: migration[:raw_content],
            version: migration[:version]
          ),
          risk_score: risk[:score],
          risk_level: risk[:level]
        }
      end

      def serialize_detail(migration, snapshot_result, warnings, risk)
        schema_before_tables = snapshot_result[:schema_before][:tables]
        schema_after_tables  = snapshot_result[:schema_after][:tables]
        diff = snapshot_result[:diff]
        changed_tables = (
          diff[:added_tables] +
          diff[:removed_tables] +
          diff[:modified_tables].keys
        ).uniq

        {
          version: migration[:version],
          name: migration[:name],
          raw_content: Migflow.configuration.expose_raw_content ? migration[:raw_content] : nil,
          schema_after: { tables: schema_after_tables },
          diff: diff,
          **serialize_schema_patches(
            from_tables: schema_before_tables,
            to_tables: schema_after_tables,
            changed_tables: changed_tables
          ),
          warnings: warnings.map { |w| serialize_warning(w) },
          risk_score: risk[:score],
          risk_level: risk[:level],
          risk_factors: risk[:factors]
        }
      end

      def serialize_warning(warning)
        {
          rule: warning.rule,
          severity: warning.severity,
          table: warning.table,
          column: warning.column,
          message: warning.message
        }
      end

      def compute_risk(migration, all_migrations)
        result   = Services::SnapshotBuilder.call(migrations: all_migrations, up_to_version: migration[:version])
        snapshot = snapshot_model_from(result[:schema_after], migration[:version])
        warnings = Services::ScopedMigrationWarnings.call(snapshot: snapshot, migration: migration, diff: result[:diff])
        Services::RiskScorer.new.call(warnings)
      end
    end
  end
end
