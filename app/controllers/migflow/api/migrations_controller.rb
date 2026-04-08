# frozen_string_literal: true

module Migflow
  module Api
    class MigrationsController < ApplicationController
      def index
        migrations = Parsers::MigrationParser.call(migrations_path: migrations_path)
        render_json(migrations: migrations.map { |m| serialize_summary(m) })
      end

      def show
        migrations = Parsers::MigrationParser.call(migrations_path: migrations_path)
        migration  = migrations.find { |m| m[:version] == params[:id] }

        return render_error("Migration not found", status: :not_found) unless migration

        result   = Services::SnapshotBuilder.call(migrations: migrations, up_to_version: params[:id])
        snapshot = snapshot_model_from(result[:schema_after], migration[:version])
        warnings = Services::ScopedMigrationWarnings.call(snapshot: snapshot, migration: migration)

        render_json(migration: serialize_detail(migration, result[:schema_after], result[:diff], warnings))
      end

      private

      def snapshot_model_from(schema_after, version)
        Models::MigrationSnapshot.new(
          version:     version,
          name:        "Historical schema",
          tables:      schema_after[:tables],
          raw_content: ""
        )
      end

      def serialize_summary(migration)
        {
          version:  migration[:version],
          name:     migration[:name],
          filename: migration[:filename],
          summary:  Services::MigrationSummaryBuilder.call(
            raw_content: migration[:raw_content],
            version: migration[:version]
          )
        }
      end

      def serialize_detail(migration, schema_after, diff, warnings)
        {
          version:      migration[:version],
          name:         migration[:name],
          raw_content:  migration[:raw_content],
          schema_after: { tables: schema_after[:tables] },
          diff:         diff,
          warnings:     warnings.map { |w| serialize_warning(w) }
        }
      end

      def serialize_warning(warning)
        {
          rule:     warning.rule,
          severity: warning.severity,
          table:    warning.table,
          column:   warning.column,
          message:  warning.message
        }
      end

    end
  end
end
