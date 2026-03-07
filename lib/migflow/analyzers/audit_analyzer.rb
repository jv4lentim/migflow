# frozen_string_literal: true

require_relative "rules/base_rule"
require_relative "rules/missing_index_rule"
require_relative "rules/missing_foreign_key_rule"
require_relative "rules/string_without_limit_rule"
require_relative "rules/missing_timestamps_rule"
require_relative "rules/dangerous_migration_rule"
require_relative "rules/null_column_without_default_rule"

module Migflow
  module Analyzers
    class AuditAnalyzer
      RULES = [
        Rules::MissingIndexRule,
        Rules::MissingForeignKeyRule,
        Rules::StringWithoutLimitRule,
        Rules::MissingTimestampsRule,
        Rules::DangerousMigrationRule,
        Rules::NullColumnWithoutDefaultRule
      ].freeze

      def self.call(snapshot:, raw_migrations: [])
        new(snapshot: snapshot, raw_migrations: raw_migrations).analyze
      end

      def initialize(snapshot:, raw_migrations:)
        @snapshot        = snapshot
        @raw_migrations  = raw_migrations
      end

      def analyze
        schema_warnings + migration_warnings
      end

      private

      def schema_warnings
        RULES.flat_map do |rule_class|
          rule_class.new.call(@snapshot.tables)
        rescue StandardError => e
          Rails.logger.error "[Migflow] Rule #{rule_class} failed: #{e.message}"
          []
        end
      end

      def migration_warnings
        [
          Rules::DangerousMigrationRule.new.call_with_migrations(@raw_migrations),
          Rules::NullColumnWithoutDefaultRule.new.call_with_migrations(@raw_migrations)
        ].flatten
      rescue StandardError => e
        Rails.logger.error "[Migflow] Migration analysis failed: #{e.message}"
        []
      end
    end
  end
end
