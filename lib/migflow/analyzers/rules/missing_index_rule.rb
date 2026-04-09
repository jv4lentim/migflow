# frozen_string_literal: true

module Migflow
  module Analyzers
    module Rules
      class MissingIndexRule < BaseRule
        def call(tables)
          tables.flat_map do |table_name, table|
            foreign_key_columns(table).reject { |col| indexed?(col, table) }.map do |col|
              warning(
                table: table_name,
                column: col[:name],
                message: "Column '#{col[:name]}' looks like a foreign key but has no index",
                severity: :warning
              )
            end
          end
        end

        private

        def foreign_key_columns(table)
          table[:columns].select { |col| col[:name].end_with?("_id") }
        end

        def indexed?(column, table)
          table[:indexes].any? { |idx| idx[:columns].include?(column[:name]) }
        end
      end
    end
  end
end
