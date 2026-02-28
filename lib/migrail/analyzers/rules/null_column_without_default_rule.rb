# frozen_string_literal: true

module Migrail
  module Analyzers
    module Rules
      class NullColumnWithoutDefaultRule < BaseRule
        ADD_COLUMN_PATTERN = /add_column\s+[:"'](\w+)[:"']?,\s+[:"'](\w+)[:"']?,\s+:\w+(.*)/

        def call(tables)
          []
        end

        def call_with_migrations(raw_migrations)
          raw_migrations.flat_map do |migration|
            detect_dangerous_columns(migration[:raw_content])
          end
        end

        private

        def detect_dangerous_columns(content)
          content.scan(ADD_COLUMN_PATTERN).filter_map do |table, column, options|
            next if nullable?(options) || has_default?(options)

            warning(
              table:    table,
              column:   column,
              message:  "NOT NULL column '#{column}' added to '#{table}' without a default — locks deploys on large tables",
              severity: :error
            )
          end
        end

        def nullable?(options)
          options.match?(/null:\s*true/)
        end

        def has_default?(options)
          options.match?(/default:\s*\S+/)
        end
      end
    end
  end
end
