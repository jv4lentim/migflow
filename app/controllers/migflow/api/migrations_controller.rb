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
        warnings = Analyzers::AuditAnalyzer.call(snapshot: snapshot, raw_migrations: [migration])

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
          summary:  infer_summary(migration)
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

      def infer_summary(migration)
        content = migration[:raw_content]

        tables = content.scan(/create_table\s+[:"'](\w+)/).flatten
        return "Created table #{tables.join(', ')}" if tables.any?

        dropped = content.scan(/drop_table\s+[:"'](\w+)/).flatten
        return "Dropped table #{dropped.join(', ')}" if dropped.any?

        cols = content.scan(/add_column\s+[:"'](\w+)[:"']?,\s*[:"'](\w+)/).map { |t, c| "#{c} to #{t}" }
        refs = content.scan(/add_(?:reference|belongs_to)\s+[:"'](\w+)[:"']?,\s*[:"'](\w+)/).map { |t, r| "#{r}_id to #{t}" }
        added = cols + refs
        return "Added #{added.join(', ')}" if added.any?

        "Migration #{migration[:version]}"
      end
    end
  end
end
