# frozen_string_literal: true

module Migflow
  module Parsers
    class SchemaParser
      VERSION_PATTERN     = /ActiveRecord::Schema(?:\[[\d.]+\])?\.define\(version:\s*([\d_]+)\)/
      CREATE_TABLE_PATTERN = /create_table\s+"([^"]+)"/
      COLUMN_PATTERN      = /t\.(\w+)\s+"([^"]+)"(.*)/
      INDEX_PATTERN       = /add_index\s+"([^"]+)",\s+(\[.*?\]|"[^"]+"|'[^']+')(.*)/
      UNIQUE_PATTERN      = /unique:\s*true/
      NULL_PATTERN        = /null:\s*(true|false)/
      DEFAULT_PATTERN     = /default:\s*([^,\n]+)/
      LIMIT_PATTERN       = /limit:\s*(\d+)/

      def self.call(schema_path:)
        new(schema_path: schema_path).parse
      end

      def initialize(schema_path:)
        @schema_path = Pathname.new(schema_path)
      end

      def parse
        content = @schema_path.read
        {
          version: extract_version(content),
          tables:  extract_tables(content)
        }
      end

      private

      def extract_version(content)
        match = VERSION_PATTERN.match(content)
        match ? match[1].delete("_") : nil
      end

      def extract_tables(content)
        tables = {}
        table_blocks(content).each do |table_name, block|
          tables[table_name] = {
            columns: parse_columns(block),
            indexes: []
          }
        end
        parse_indexes(content, tables)
        tables
      end

      def table_blocks(content)
        blocks = {}
        content.scan(/create_table\s+"([^"]+)"[^\n]*\n(.*?)end/m) do |name, body|
          blocks[name] = body
        end
        blocks
      end

      def parse_columns(block)
        block.scan(COLUMN_PATTERN).map do |type, name, options|
          build_column(name, type, options)
        end
      end

      def build_column(name, type, options)
        null_match    = NULL_PATTERN.match(options)
        default_match = DEFAULT_PATTERN.match(options)
        limit_match   = LIMIT_PATTERN.match(options)

        column = {
          name:    name,
          type:    type,
          null:    null_match ? null_match[1] == "true" : true,
          default: default_match ? default_match[1].strip : nil
        }
        column[:limit] = limit_match[1].to_i if limit_match
        column
      end

      def parse_indexes(content, tables)
        content.scan(INDEX_PATTERN) do |table, columns_raw, options|
          next unless tables.key?(table)

          tables[table][:indexes] << build_index(columns_raw, options)
        end
      end

      def build_index(columns_raw, options)
        name_match = /name:\s*"([^"]+)"/.match(options)
        {
          name:    name_match ? name_match[1] : nil,
          columns: parse_index_columns(columns_raw),
          unique:  UNIQUE_PATTERN.match?(options)
        }
      end

      def parse_index_columns(raw)
        if raw.start_with?("[")
          raw.scan(/"([^"]+)"/).flatten
        else
          [raw.delete("\"'")]
        end
      end
    end
  end
end
