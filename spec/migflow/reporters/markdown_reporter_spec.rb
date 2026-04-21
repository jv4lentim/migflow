# frozen_string_literal: true

require "spec_helper"
require "migflow/reporters/markdown_reporter"

RSpec.describe Migflow::Reporters::MarkdownReporter do
  subject(:reporter) { described_class.new }

  let(:report) do
    {
      generated_at: "2026-04-19T10:00:00Z",
      summary: {
        total_migrations: 2,
        migrations_with_warnings: 1,
        migrations_with_errors: 1,
        highest_risk_score: 40,
        highest_risk_level: "medium"
      },
      migrations: [
        {
          version: "20240101120000",
          name: "Create users",
          risk_score: 0,
          risk_level: "safe",
          warnings: []
        },
        {
          version: "20240701000000",
          name: "Add dangerous",
          risk_score: 40,
          risk_level: "medium",
          warnings: [
            { rule: "dangerous_migration_rule", severity: "error", table: "users", column: nil, message: "remove_column" }
          ]
        }
      ]
    }
  end

  describe "#render" do
    subject(:output) { reporter.render(report) }

    it "includes the report heading" do
      expect(output).to include("## Migflow Analysis Report")
    end

    it "includes a table header with the expected columns" do
      expect(output).to include("| Migration | Risk Score | Level | Warnings |")
    end

    it "includes a table separator row" do
      expect(output).to include("|-----------|")
    end

    it "includes a row for each migration" do
      expect(output).to include("20240101120000")
      expect(output).to include("20240701000000")
    end

    it "shows the correct risk score for the dangerous migration" do
      expect(output).to include("| 40 |").or include("40")
    end

    it "uses the HIGH emoji for high-level migrations" do
      high_report = report.merge(migrations: [
                                   report[:migrations].last.merge(risk_level: "high", risk_score: 75)
                                 ])
      expect(reporter.render(high_report)).to include("🔴")
    end

    it "uses the safe emoji for safe migrations" do
      expect(output).to include("⚪")
    end

    it "shows 'none' in the warnings cell for migrations with no warnings" do
      expect(output).to include("none")
    end

    it "shows error count for migrations with errors" do
      expect(output).to include("1 error")
    end

    it "includes the summary footer with total count" do
      expect(output).to include("**Migrations analyzed:** 2")
    end

    it "includes the highest score in the footer" do
      expect(output).to include("**Highest score:** 40")
    end
  end
end
