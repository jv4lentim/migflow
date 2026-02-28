# frozen_string_literal: true

module Migrail
  module Analyzers
    module Rules
      class DangerousMigrationRule < BaseRule
        DANGEROUS_OPERATIONS = {
          remove_column:  "Removes a column — may break running app instances",
          drop_table:     "Drops a table — destructive and irreversible",
          rename_column:  "Renames a column — breaks existing queries and code"
        }.freeze

        def call(tables)
          []
        end

        def call_with_migrations(raw_migrations)
          raw_migrations.flat_map do |migration|
            detect_dangers(migration[:raw_content], migration[:filename])
          end
        end

        private

        def detect_dangers(content, filename)
          DANGEROUS_OPERATIONS.filter_map do |operation, message|
            next unless content.match?(/\b#{operation}\b/)

            warning(
              table:    extract_table(content, operation),
              message:  "#{filename}: #{message}",
              severity: :error
            )
          end
        end

        def extract_table(content, operation)
          match = content.match(/#{operation}\s*[:(]\s*[:"']?(\w+)/)
          match ? match[1] : "unknown"
        end
      end
    end
  end
end
