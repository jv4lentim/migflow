# frozen_string_literal: true

module Migflow
  module Parsers
    class MigrationParser
      FILENAME_PATTERN = /\A(\d+)_(.+)\.rb\z/

      def self.call(migrations_path:)
        new(migrations_path: migrations_path).parse
      end

      def initialize(migrations_path:)
        @migrations_path = Pathname.new(migrations_path)
      end

      def parse
        migration_files
          .map { |file| build_entry(file) }
          .compact
          .sort_by { |entry| entry[:version] }
      end

      private

      def migration_files
        return [] unless @migrations_path.directory?

        @migrations_path.glob("*.rb")
      end

      def build_entry(file)
        match = FILENAME_PATTERN.match(file.basename.to_s)
        return nil unless match

        version  = match[1]
        raw_name = match[2]

        {
          version:     version,
          name:        humanize(raw_name),
          filename:    file.basename.to_s,
          filepath:    file,
          raw_content: file.read
        }
      end

      def humanize(raw_name)
        raw_name.gsub("_", " ").capitalize
      end
    end
  end
end
