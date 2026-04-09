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

        result = build_diff(migrations, from_data, to_data)
        render_json(diff: serialize_diff(result))
      end

      private

      def from_version = params[:from]
      def to_version   = params[:to]

      def find_migration(migrations, version)
        migrations.find { |m| m[:version] == version }
      end

      def build_diff(migrations, from_data, to_data)
        ordered = migrations.sort_by { |migration| migration[:version] }
        from_idx = ordered.find_index { |migration| migration[:version] == from_data[:version] }
        previous_from = from_idx && from_idx.positive? ? ordered[from_idx - 1] : nil

        from_tables = if previous_from
                        previous_result = Services::SnapshotBuilder.call(migrations: migrations, up_to_version: previous_from[:version])
                        previous_result[:schema_after][:tables]
                      else
                        {}
                      end
        to_result   = Services::SnapshotBuilder.call(migrations: migrations, up_to_version: to_data[:version])

        diff = Services::DiffBuilder.call(
          from_tables:  from_tables,
          to_tables:    to_result[:schema_after][:tables],
          from_version: from_data[:version],
          to_version:   to_data[:version]
        )

        {
          diff: diff,
          from_tables: from_tables,
          to_tables: to_result[:schema_after][:tables]
        }
      end

      def serialize_diff(result)
        diff = result[:diff]
        changed_tables = diff.changes.map(&:table).uniq

        {
          from_version: diff.from_version,
          to_version:   diff.to_version,
          changes:      diff.changes.map { |c| { type: c.type, table: c.table, detail: c.detail } },
          **serialize_schema_patches(
            from_tables: result[:from_tables],
            to_tables: result[:to_tables],
            changed_tables: changed_tables
          )
        }
      end
    end
  end
end
