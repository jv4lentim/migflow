# frozen_string_literal: true

require "spec_helper"
require "migflow/reporters/json_reporter"

RSpec.describe Migflow::Reporters::JsonReporter do
  subject(:reporter) { described_class.new }

  let(:report) do
    {
      generated_at: "2026-04-19T10:00:00Z",
      summary: {
        total_migrations: 2,
        migrations_with_warnings: 1,
        migrations_with_errors: 0,
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
            { rule: "dangerous_migration_rule", severity: "error", table: "users", column: nil, message: "remove_column detected" }
          ]
        }
      ]
    }
  end

  describe "#render" do
    subject(:output) { reporter.render(report) }

    it "returns valid JSON" do
      expect { JSON.parse(output) }.not_to raise_error
    end

    it "includes generated_at" do
      expect(JSON.parse(output)["generated_at"]).to eq("2026-04-19T10:00:00Z")
    end

    it "includes all migrations" do
      parsed = JSON.parse(output)
      expect(parsed["migrations"].size).to eq(2)
    end

    it "includes summary with highest_risk_score" do
      parsed = JSON.parse(output)
      expect(parsed["summary"]["highest_risk_score"]).to eq(40)
    end

    it "uses pretty-printing (contains newlines)" do
      expect(output).to include("\n")
    end
  end
end
