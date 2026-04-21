# frozen_string_literal: true

require "spec_helper"
require "migflow/services/report_generator"
require "migflow/services/snapshot_builder"
require "migflow/services/scoped_migration_warnings"
require "migflow/services/risk_scorer"
require "migflow/analyzers/audit_analyzer"

RSpec.describe Migflow::Services::ReportGenerator do
  subject(:generator) { described_class.new }

  let(:migrations_path) { FIXTURES_PATH.join("migrations") }

  describe "#call" do
    subject(:report) { generator.call(migrations_path: migrations_path) }

    it "returns a report hash with the expected top-level keys" do
      expect(report.keys).to contain_exactly(:generated_at, :summary, :migrations)
    end

    it "sets generated_at to a UTC ISO-8601 timestamp" do
      expect(report[:generated_at]).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/)
    end

    describe "migrations list" do
      it "includes one entry per migration file" do
        expect(report[:migrations].size).to eq(3)
      end

      it "lists migrations in version order" do
        versions = report[:migrations].map { |m| m[:version] }
        expect(versions).to eq(versions.sort)
      end

      it "includes the required keys on each entry" do
        report[:migrations].each do |m|
          expect(m.keys).to include(:version, :name, :risk_score, :risk_level, :warnings)
        end
      end

      it "includes a numeric risk_score between 0 and 100" do
        report[:migrations].each do |m|
          expect(m[:risk_score]).to be_between(0, 100)
        end
      end

      it "assigns a high risk_level to the dangerous migration" do
        dangerous = report[:migrations].find { |m| m[:version] == "20240701000000" }
        expect(dangerous[:risk_level]).to eq("high")
      end

      it "serializes warnings with rule, severity, table, column, message" do
        dangerous = report[:migrations].find { |m| m[:version] == "20240701000000" }
        warning = dangerous[:warnings].first
        expect(warning.keys).to include(:rule, :severity, :table, :column, :message)
      end
    end

    describe "summary" do
      it "reports the correct total_migrations count" do
        expect(report[:summary][:total_migrations]).to eq(3)
      end

      it "reports highest_risk_level as high (dangerous migration present)" do
        expect(report[:summary][:highest_risk_level]).to eq("high")
      end

      it "reports highest_risk_score > 0" do
        expect(report[:summary][:highest_risk_score]).to be > 0
      end

      it "reports migrations_with_warnings >= 1" do
        expect(report[:summary][:migrations_with_warnings]).to be >= 1
      end

      it "includes migrations_with_errors in the summary" do
        expect(report[:summary]).to have_key(:migrations_with_errors)
      end
    end

    context "with an empty migrations directory" do
      let(:migrations_path) { FIXTURES_PATH.join("nonexistent") }

      it "returns an empty migrations list" do
        expect(report[:migrations]).to be_empty
      end

      it "returns zero for all summary counts" do
        expect(report[:summary][:total_migrations]).to eq(0)
        expect(report[:summary][:highest_risk_score]).to eq(0)
        expect(report[:summary][:highest_risk_level]).to eq("safe")
      end
    end
  end
end
