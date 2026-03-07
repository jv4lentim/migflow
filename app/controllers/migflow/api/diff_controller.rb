# frozen_string_literal: true

module Migflow
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
        from_result = Services::SnapshotBuilder.call(migrations: migrations, up_to_version: from_data[:version])
        to_result   = Services::SnapshotBuilder.call(migrations: migrations, up_to_version: to_data[:version])

        Services::DiffBuilder.call(
          from_tables:  from_result[:schema_after][:tables],
          to_tables:    to_result[:schema_after][:tables],
          from_version: from_data[:version],
          to_version:   to_data[:version]
        )
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
