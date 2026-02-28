# frozen_string_literal: true

module Migrail
  module Api
    class DiffController < ApplicationController
      def show
        return render_error("params 'from' and 'to' are required") unless from_version && to_version

        migrations = Parsers::MigrationParser.call(migrations_path: migrations_path)
        from_data  = find_migration(migrations, from_version)
        to_data    = find_migration(migrations, to_version)

        return render_error("One or both migrations not found", status: :not_found) unless from_data && to_data

        diff = build_diff(migrations, from_data, to_data)
        render_json(diff: serialize_diff(diff))
      end

      private

      def from_version = params[:from]
      def to_version   = params[:to]

      def find_migration(migrations, version)
        migrations.find { |m| m[:version] == version }
      end

      def build_diff(migrations, from_data, to_data)
        from_schema = build_partial_schema(migrations, from_data[:version])
        to_schema   = build_partial_schema(migrations, to_data[:version])

        Services::DiffBuilder.call(
          from_tables:  from_schema,
          to_tables:    to_schema,
          from_version: from_data[:version],
          to_version:   to_data[:version]
        )
      end

      def build_partial_schema(migrations, up_to_version)
        relevant = migrations.select { |m| m[:version] <= up_to_version }
        snapshot = Services::SchemaBuilder.call(schema_path: schema_path)
        return snapshot.tables if relevant.size == migrations.size

        snapshot.tables
      end

      def serialize_diff(diff)
        {
          from_version: diff.from_version,
          to_version:   diff.to_version,
          changes:      diff.changes.map { |c| { type: c.type, table: c.table, detail: c.detail } }
        }
      end
    end
  end
end
