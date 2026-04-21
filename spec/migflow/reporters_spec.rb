# frozen_string_literal: true

require "spec_helper"
require "migflow/reporters"

RSpec.describe Migflow::Reporters do
  describe ".for" do
    it "returns a JsonReporter for :json" do
      expect(described_class.for(:json)).to be_a(Migflow::Reporters::JsonReporter)
    end

    it "returns a MarkdownReporter for :markdown" do
      expect(described_class.for(:markdown)).to be_a(Migflow::Reporters::MarkdownReporter)
    end

    it "accepts string format names" do
      expect(described_class.for("json")).to be_a(Migflow::Reporters::JsonReporter)
    end

    it "raises ArgumentError for unknown formats" do
      expect { described_class.for(:xml) }.to raise_error(ArgumentError, /Unknown format/)
    end
  end

  describe ".resolve_threshold" do
    it "returns nil when FAIL_ON is nil" do
      expect(described_class.resolve_threshold(nil)).to be_nil
    end

    it "returns nil when FAIL_ON is empty string" do
      expect(described_class.resolve_threshold("")).to be_nil
    end

    it "parses a numeric string as an integer threshold" do
      expect(described_class.resolve_threshold("40")).to eq(40)
    end

    it "maps 'high' to 71 (minimum high boundary)" do
      expect(described_class.resolve_threshold("high")).to eq(71)
    end

    it "maps 'medium' to 31 (minimum medium boundary)" do
      expect(described_class.resolve_threshold("medium")).to eq(31)
    end

    it "maps 'low' to 1 (minimum low boundary)" do
      expect(described_class.resolve_threshold("low")).to eq(1)
    end

    it "is case-insensitive for level names" do
      expect(described_class.resolve_threshold("HIGH")).to eq(71)
    end

    it "raises ArgumentError for unknown level names" do
      expect { described_class.resolve_threshold("critical") }.to raise_error(ArgumentError, /Unknown FAIL_ON level/)
    end
  end
end
