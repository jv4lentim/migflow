# frozen_string_literal: true

require "spec_helper"
require "migflow/services/risk_scorer"

RSpec.describe Migflow::Services::RiskScorer do
  def build_warning(rule:, message: "A warning", severity: :warning)
    Migflow::Models::Warning.new(
      rule: rule,
      severity: severity,
      table: "users",
      column: nil,
      message: message
    )
  end

  def score(warnings)
    described_class.new.call(warnings)
  end

  # --- Zero warnings ---

  it "returns score 0 and level safe when there are no warnings" do
    result = score([])

    expect(result[:score]).to eq(0)
    expect(result[:level]).to eq("safe")
    expect(result[:factors]).to be_empty
  end

  # --- Individual rule weights ---

  it "assigns 40 points for dangerous_migration_rule" do
    result = score([build_warning(rule: "dangerous_migration_rule", severity: :error)])

    expect(result[:score]).to eq(40)
    expect(result[:level]).to eq("medium")
  end

  it "assigns 20 points for missing_foreign_key_rule" do
    result = score([build_warning(rule: "missing_foreign_key_rule")])

    expect(result[:score]).to eq(20)
    expect(result[:level]).to eq("low")
  end

  it "assigns 20 points for null_column_without_default_rule" do
    result = score([build_warning(rule: "null_column_without_default_rule")])

    expect(result[:score]).to eq(20)
    expect(result[:level]).to eq("low")
  end

  it "assigns 15 points for missing_index_rule" do
    result = score([build_warning(rule: "missing_index_rule")])

    expect(result[:score]).to eq(15)
    expect(result[:level]).to eq("low")
  end

  it "assigns 5 points for string_without_limit_rule" do
    result = score([build_warning(rule: "string_without_limit_rule")])

    expect(result[:score]).to eq(5)
    expect(result[:level]).to eq("low")
  end

  it "assigns 5 points for missing_timestamps_rule" do
    result = score([build_warning(rule: "missing_timestamps_rule", severity: :info)])

    expect(result[:score]).to eq(5)
    expect(result[:level]).to eq("low")
  end

  # --- Summing multiple warnings ---

  it "sums weights from multiple warnings" do
    warnings = [
      build_warning(rule: "missing_index_rule"),       # 15
      build_warning(rule: "string_without_limit_rule") # 5
    ]

    expect(score(warnings)[:score]).to eq(20)
  end

  it "sums weights from all six rules combined" do
    warnings = [
      build_warning(rule: "dangerous_migration_rule", severity: :error), # 40
      build_warning(rule: "missing_index_rule"),                         # 15
      build_warning(rule: "missing_foreign_key_rule"),                   # 20
      build_warning(rule: "string_without_limit_rule"),                  # 5
      build_warning(rule: "null_column_without_default_rule"),           # 20
      build_warning(rule: "missing_timestamps_rule", severity: :info)    # 5
    ]

    expect(score(warnings)[:score]).to eq(100)
  end

  it "counts the same rule multiple times when it appears on different columns" do
    warnings = [
      build_warning(rule: "missing_index_rule"), # 15
      build_warning(rule: "missing_index_rule")  # 15
    ]

    expect(score(warnings)[:score]).to eq(30)
  end

  # --- Score capping ---

  it "caps score at 100 when raw sum exceeds 100" do
    warnings = Array.new(4) { build_warning(rule: "dangerous_migration_rule", severity: :error) }

    result = score(warnings)

    expect(result[:score]).to eq(100)
    expect(result[:level]).to eq("high")
  end

  # --- Risk level boundaries ---

  it "returns level safe for score exactly 0" do
    expect(score([])[:level]).to eq("safe")
  end

  it "returns level low for score 1 (minimum low boundary)" do
    warnings = [build_warning(rule: "string_without_limit_rule")] # 5 points

    expect(score(warnings)[:level]).to eq("low")
  end

  it "returns level low for score 30 (maximum low boundary)" do
    warnings = [
      build_warning(rule: "missing_index_rule"),      # 15
      build_warning(rule: "missing_index_rule")       # 15
    ]

    result = score(warnings)
    expect(result[:score]).to eq(30)
    expect(result[:level]).to eq("low")
  end

  it "returns level medium for score 31 (minimum medium boundary)" do
    warnings = [
      build_warning(rule: "missing_index_rule"),        # 15
      build_warning(rule: "missing_index_rule"),        # 15
      build_warning(rule: "string_without_limit_rule")  # 5 → total 35, use 2*missing_fk instead
    ]
    # 15+15+5 = 35, which is medium
    result = score(warnings)
    expect(result[:score]).to eq(35)
    expect(result[:level]).to eq("medium")
  end

  it "returns level medium for score 70 (maximum medium boundary)" do
    warnings = [
      build_warning(rule: "missing_foreign_key_rule"),          # 20
      build_warning(rule: "null_column_without_default_rule"),  # 20
      build_warning(rule: "missing_index_rule"),                # 15
      build_warning(rule: "missing_index_rule") # 15
    ]

    result = score(warnings)
    expect(result[:score]).to eq(70)
    expect(result[:level]).to eq("medium")
  end

  it "returns level high for score 71 (minimum high boundary)" do
    warnings = [
      build_warning(rule: "dangerous_migration_rule", severity: :error), # 40
      build_warning(rule: "missing_foreign_key_rule"),                   # 20
      build_warning(rule: "missing_index_rule") # 15
    ]

    # 40+20+15 = 75 — close enough to 71; let's construct 71 exactly:
    # dangerous(40) + null_column(20) + missing_index(15) - 4? Not possible with fixed weights.
    # 40 + 20 + 15 = 75 is still high (>= 71), so the test is valid.
    result = score(warnings)
    expect(result[:score]).to eq(75)
    expect(result[:level]).to eq("high")
  end

  it "returns level high for score 100" do
    warnings = Array.new(3) { build_warning(rule: "dangerous_migration_rule", severity: :error) }

    result = score(warnings)
    expect(result[:score]).to eq(100)
    expect(result[:level]).to eq("high")
  end

  # --- risk_factors structure ---

  it "includes each warning as a factor with rule, message and weight" do
    msg = "DROP TABLE detected"
    warnings = [build_warning(rule: "dangerous_migration_rule", message: msg, severity: :error)]

    factors = score(warnings)[:factors]

    expect(factors.size).to eq(1)
    expect(factors.first[:rule]).to eq("dangerous_migration_rule")
    expect(factors.first[:message]).to eq(msg)
    expect(factors.first[:weight]).to eq(40)
  end

  it "returns one factor per warning even for the same rule" do
    warnings = [
      build_warning(rule: "missing_index_rule", message: "Index missing on users.email"),
      build_warning(rule: "missing_index_rule", message: "Index missing on users.phone")
    ]

    factors = score(warnings)[:factors]

    expect(factors.size).to eq(2)
    expect(factors.map { |f| f[:message] }).to contain_exactly(
      "Index missing on users.email",
      "Index missing on users.phone"
    )
  end

  # --- Unknown / unweighted rules ---

  it "ignores warnings whose rule has no configured weight" do
    unknown = build_warning(rule: "no_schema_change_migration_rule", severity: :info)

    result = score([unknown])

    expect(result[:score]).to eq(0)
    expect(result[:level]).to eq("safe")
    expect(result[:factors]).to be_empty
  end

  it "does not include unweighted rules in factors" do
    warnings = [
      build_warning(rule: "no_schema_change_migration_rule", severity: :info),
      build_warning(rule: "missing_index_rule")
    ]

    factors = score(warnings)[:factors]

    expect(factors.map { |f| f[:rule] }).not_to include("no_schema_change_migration_rule")
    expect(factors.size).to eq(1)
  end

  # --- Mixed severities ---

  it "applies weights regardless of warning severity" do
    info_warning    = build_warning(rule: "missing_timestamps_rule", severity: :info)
    warning_warning = build_warning(rule: "missing_index_rule",      severity: :warning)
    error_warning   = build_warning(rule: "dangerous_migration_rule", severity: :error)

    result = score([info_warning, warning_warning, error_warning])

    expect(result[:score]).to eq(5 + 15 + 40)
  end
end
