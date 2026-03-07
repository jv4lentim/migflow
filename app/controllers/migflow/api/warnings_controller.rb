# frozen_string_literal: true

module Migflow
  module Api
    class WarningsController < ApplicationController
      def index
        snapshot    = Services::SchemaBuilder.call(schema_path: schema_path)
        migrations  = Parsers::MigrationParser.call(migrations_path: migrations_path)
        warnings    = Analyzers::AuditAnalyzer.call(snapshot: snapshot, raw_migrations: migrations)

        render_json(warnings: warnings.map { |w| serialize(w) })
      end

      private

      def serialize(warning)
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
