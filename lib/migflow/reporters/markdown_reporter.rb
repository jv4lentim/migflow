# frozen_string_literal: true

module Migflow
  module Reporters
    class MarkdownReporter
      LEVEL_EMOJI = {
        "high" => "🔴",
        "medium" => "🟡",
        "low" => "🟢",
        "safe" => "⚪"
      }.freeze

      def render(report)
        lines = []
        lines << "## Migflow Analysis Report\n"
        lines << build_table(report[:migrations])
        lines << ""
        lines << build_footer(report[:summary])
        lines.join("\n")
      end

      private

      def build_table(migrations)
        rows = migrations.map do |m|
          errors   = m[:warnings].count { |w| w[:severity] == "error" }
          warnings = m[:warnings].count { |w| w[:severity] == "warning" }
          emoji    = LEVEL_EMOJI.fetch(m[:risk_level], "⚪")
          label    = "#{emoji} #{m[:risk_level].upcase}"
          warning_summary = warning_cell(errors, warnings)

          "| #{m[:version]} #{m[:name]} | #{m[:risk_score]} | #{label} | #{warning_summary} |"
        end

        [
          "| Migration | Risk Score | Level | Warnings |",
          "|-----------|------------|-------|----------|",
          *rows
        ].join("\n")
      end

      def warning_cell(errors, warnings)
        parts = []
        parts << "#{errors} #{"error".then { |s| errors == 1 ? s : "#{s}s" }}" if errors.positive?
        parts << "#{warnings} #{"warning".then { |s| warnings == 1 ? s : "#{s}s" }}" if warnings.positive?
        parts.empty? ? "none" : parts.join(", ")
      end

      def build_footer(summary)
        [
          "**Migrations analyzed:** #{summary[:total_migrations]}",
          "**With issues:** #{summary[:migrations_with_warnings]}",
          "**Highest score:** #{summary[:highest_risk_score]}"
        ].join(" | ")
      end
    end
  end
end
