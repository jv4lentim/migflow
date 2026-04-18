# frozen_string_literal: true

require "spec_helper"

RSpec.describe Migflow do
  it "has a version number" do
    expect(Migflow::VERSION).not_to be_nil
  end

  it "exposes key constants" do
    expect(defined?(Migflow::Parsers::MigrationParser)).to be_truthy
    expect(defined?(Migflow::Services::SnapshotBuilder)).to be_truthy
  end
end
