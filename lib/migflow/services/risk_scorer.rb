# frozen_string_literal: true

module Migflow
  module Services
    class RiskScorer
      RULE_WEIGHTS = {
        "dangerous_migration_rule" => 40,
        "missing_index_rule" => 15,
        "missing_foreign_key_rule" => 20,
        "string_without_limit_rule" => 5,
        "null_column_without_default_rule" => 20,
        "missing_timestamps_rule" => 5
      }.freeze

      LEVELS = [
        { min: 71, max: 100, level: "high" },
        { min: 31, max: 70,  level: "medium" },
        { min: 1,  max: 30,  level: "low" },
        { min: 0,  max: 0,   level: "safe" }
      ].freeze

      def call(warnings)
        factors = warnings.filter_map do |w|
          weight = RULE_WEIGHTS[w.rule]
          next unless weight

          { rule: w.rule, message: w.message, weight: weight }
        end

        raw = factors.sum { |f| f[:weight] }
        score = [raw, 100].min
        level = LEVELS.find { |l| score.between?(l[:min], l[:max]) }&.fetch(:level, "safe")

        { score: score, level: level, factors: factors }
      end
    end
  end
end
