# frozen_string_literal: true

require "spec_helper"

RSpec.describe Migflow::Parsers::MigrationParser do
  let(:migrations_path) { FIXTURES_PATH.join("migrations") }
  let(:parsed) { described_class.call(migrations_path: migrations_path) }

  it "returns the correct number of migrations" do
    expect(parsed.size).to eq(3)
  end

  it "sorts by version ascending" do
    versions = parsed.map { |m| m[:version] }
    expect(versions).to eq(versions.sort)
  end

  it "extracts version from filename" do
    expect(parsed.first[:version]).to eq("20240101120000")
  end

  it "humanizes migration name" do
    expect(parsed.first[:name]).to eq("Create users")
  end

  it "humanizes name for add migration" do
    expect(parsed[1][:name]).to eq("Add posts")
  end

  it "sets correct filename" do
    expect(parsed.first[:filename]).to eq("20240101120000_create_users.rb")
  end

  it "reads raw content" do
    expect(parsed.first[:raw_content]).to include("create_table :users")
  end

  it "filepath is a Pathname" do
    expect(parsed.first[:filepath]).to be_a(Pathname)
  end

  it "ignores non-rb files" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "20240101_test.rb"), "# migration")
      File.write(File.join(dir, "README.md"), "# readme")
      result = described_class.call(migrations_path: dir)
      expect(result.size).to eq(1)
    end
  end

  it "returns empty for nonexistent path" do
    result = described_class.call(migrations_path: "/nonexistent/path")
    expect(result).to eq([])
  end
end
