# frozen_string_literal: true

module Migflow
  module Analyzers
    module Rules
      class MissingTimestampsRule < BaseRule
        TIMESTAMP_COLUMNS = %w[created_at updated_at].freeze
        MAX_JOIN_TABLE_COLUMNS = 3

        def call(tables)
          tables.reject { |_, table| join_table?(table) }.filter_map do |table_name, table|
            next if has_timestamps?(table)

            warning(
              table:    table_name,
              message:  "Table '#{table_name}' is missing created_at and/or updated_at",
              severity: :warning
            )
          end
        end

        private

        def has_timestamps?(table)
          column_names = table[:columns].map { |c| c[:name] }
          TIMESTAMP_COLUMNS.all? { |ts| column_names.include?(ts) }
        end

        def join_table?(table)
          columns = table[:columns]
          return false if columns.size > MAX_JOIN_TABLE_COLUMNS

          columns.all? { |col| col[:name].end_with?("_id") }
        end
      end
    end
  end
end
