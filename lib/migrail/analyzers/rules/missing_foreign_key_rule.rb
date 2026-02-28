# frozen_string_literal: true

module Migrail
  module Analyzers
    module Rules
      class MissingForeignKeyRule < BaseRule
        FOREIGN_KEY_PATTERN = /foreign_key.*references/

        def call(tables)
          tables.flat_map do |table_name, table|
            foreign_key_columns(table).map do |col|
              warning(
                table:    table_name,
                column:   col[:name],
                message:  "Column '#{col[:name]}' looks like a foreign key but has no foreign key constraint",
                severity: :info
              )
            end
          end
        end

        private

        def foreign_key_columns(table)
          table[:columns].select { |col| col[:name].end_with?("_id") }
        end
      end
    end
  end
end
