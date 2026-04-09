# frozen_string_literal: true

module Migflow
  module Services
    class SchemaBuilder
      def self.call(schema_path:)
        new(schema_path: schema_path).build
      end

      def initialize(schema_path:)
        @schema_path = schema_path
      end

      def build
        parsed = Parsers::SchemaParser.call(schema_path: @schema_path)
        Models::MigrationSnapshot.new(
          version: parsed[:version],
          name: "Current schema",
          tables: parsed[:tables],
          raw_content: Pathname.new(@schema_path).read
        )
      end
    end
  end
end
