# frozen_string_literal: true

module Migrail
  module Analyzers
    module Rules
      class BaseRule
        def call(tables)
          raise NotImplementedError
        end

        private

        def warning(table:, column: nil, message:, severity: :warning)
          Models::Warning.new(
            rule:     rule_name,
            severity: severity,
            table:    table,
            column:   column,
            message:  message
          )
        end

        def rule_name
          short = self.class.name.split("::").last
          short.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
               .gsub(/([a-z])([A-Z])/, '\1_\2')
               .downcase
        end
      end
    end
  end
end
