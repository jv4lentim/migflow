# frozen_string_literal: true

module Migflow
  module Analyzers
    module Rules
      class StringWithoutLimitRule < BaseRule
        def call(tables)
          tables.flat_map do |table_name, table|
            string_columns_without_limit(table).map do |col|
              warning(
                table:    table_name,
                column:   col[:name],
                message:  "String column '#{col[:name]}' has no limit defined",
                severity: :info
              )
            end
          end
        end

        private

        def string_columns_without_limit(table)
          table[:columns].select { |col| col[:type] == "string" && col[:limit].nil? }
        end
      end
    end
  end
end
