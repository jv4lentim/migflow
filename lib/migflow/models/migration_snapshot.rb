# frozen_string_literal: true

module Migflow
  module Models
    MigrationSnapshot = Data.define(:version, :name, :tables, :raw_content) do
      def table_names
        tables.keys.sort
      end

      def find_table(name)
        tables[name]
      end
    end
  end
end
