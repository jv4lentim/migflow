# frozen_string_literal: true

module Migrail
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

        snapshot = current_snapshot
        warnings = Analyzers::AuditAnalyzer.call(snapshot: snapshot, raw_migrations: [migration])

        render_json(migration: serialize_detail(migration, snapshot, warnings))
      end

      private

      def current_snapshot
        Services::SchemaBuilder.call(schema_path: schema_path)
      end

      def serialize_summary(migration)
        {
          version:  migration[:version],
          name:     migration[:name],
          filename: migration[:filename],
          summary:  infer_summary(migration)
        }
      end

      def serialize_detail(migration, snapshot, warnings)
        {
          version:     migration[:version],
          name:        migration[:name],
          raw_content: migration[:raw_content],
          schema:      { tables: snapshot.tables },
          warnings:    warnings.map { |w| serialize_warning(w) }
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
        tables  = content.scan(/create_table\s+"([^"]+)"/).flatten

        return "Created table #{tables.join(', ')}" if tables.any?

        "Migration #{migration[:version]}"
      end
    end
  end
end
