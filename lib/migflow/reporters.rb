# frozen_string_literal: true

require_relative "reporters/json_reporter"
require_relative "reporters/markdown_reporter"
require_relative "services/risk_scorer"

module Migflow
  module Reporters
    # Maps level names to the minimum score for that level: { "high" => 71, "medium" => 31, "low" => 1 }
    LEVEL_THRESHOLDS = Migflow::Services::RiskScorer::LEVELS
                       .reject { |l| l[:level] == "safe" }
                       .to_h { |l| [l[:level], l[:min]] }
                       .freeze

    def self.for(format)
      case format.to_sym
      when :json then JsonReporter.new
      when :markdown then MarkdownReporter.new
      else raise ArgumentError, "Unknown format: #{format}. Use 'json' or 'markdown'."
      end
    end

    # Resolves FAIL_ON value (level name or numeric string) to a minimum score threshold.
    # Returns nil if FAIL_ON is blank.
    def self.resolve_threshold(fail_on)
      return nil if fail_on.nil? || fail_on.strip.empty?

      if fail_on.match?(/\A\d+\z/)
        Integer(fail_on)
      else
        LEVEL_THRESHOLDS.fetch(fail_on.downcase) do
          raise ArgumentError,
                "Unknown FAIL_ON level '#{fail_on}'. Use low/medium/high or a numeric score."
        end
      end
    end
  end
end
