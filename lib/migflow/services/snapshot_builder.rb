# frozen_string_literal: true

require_relative "migration_dsl_scanner"

module Migflow
  module Services
    class SnapshotBuilder
      def self.call(migrations:, up_to_version:)
        new(migrations: migrations, up_to_version: up_to_version).build
      end

      def initialize(migrations:, up_to_version:)
        @migrations    = migrations.sort_by { |m| m[:version] }
        @up_to_version = up_to_version
      end

      def build
        before = { tables: {} }
        after  = { tables: {} }

        @migrations.each do |migration|
          break if migration[:version] > @up_to_version

          before = deep_copy(after)
          after  = apply_migration(after, migration[:raw_content])
        end

        { schema_before: before, schema_after: after, diff: calculate_diff(before, after) }
      end

      private

      def deep_copy(state)
        Marshal.load(Marshal.dump(state))
      end

      def apply_migration(state, content)
        s = deep_copy(state)
        scanner = MigrationDslScanner.new(content)
        apply_create_tables(s, scanner)
        apply_drop_tables(s, scanner)
        apply_add_columns(s, scanner)
        apply_remove_columns(s, scanner)
        apply_add_references(s, scanner)
        apply_remove_references(s, scanner)
        apply_rename_columns(s, scanner)
        apply_rename_indexes(s, scanner)
        apply_rename_tables(s, scanner)
        apply_change_columns(s, scanner)
        apply_change_column_defaults(s, scanner)
        apply_change_column_nulls(s, scanner)
        apply_change_column_comments(s, scanner)
        apply_add_indexes(s, scanner)
        apply_remove_indexes(s, scanner)
        apply_add_foreign_keys(s, scanner)
        apply_remove_foreign_keys(s, scanner)
        apply_add_check_constraints(s, scanner)
        apply_remove_check_constraints(s, scanner)
        apply_change_table_blocks(s, scanner)
        s
      end

      def apply_create_tables(state, scanner)
        scanner.create_table_blocks.each do |table, block|
          state[:tables][table] = {
            columns: parse_block_columns(block),
            indexes: parse_block_indexes(block),
            foreign_keys: [],
            check_constraints: []
          }
        end
      end

      def apply_drop_tables(state, scanner)
        scanner.drop_tables.each { |table| state[:tables].delete(table) }
      end

      def apply_add_columns(state, scanner)
        scanner.add_columns.each do |table, col, type, opts|
          ensure_table(state, table)
          state[:tables][table][:columns] << build_column(col, type, opts)
        end
      end

      def apply_remove_columns(state, scanner)
        scanner.remove_column.each do |table, col|
          next unless state[:tables][table]

          state[:tables][table][:columns].reject! { |c| c[:name] == col }
        end

        scanner.remove_columns.each do |table, cols_raw|
          next unless state[:tables][table]

          extract_columns_list(cols_raw).each do |col|
            state[:tables][table][:columns].reject! { |c| c[:name] == col }
          end
        end
      end

      def apply_add_references(state, scanner)
        scanner.add_references.each do |table, ref, opts|
          ensure_table(state, table)
          build_reference_columns(ref, opts).each do |column|
            state[:tables][table][:columns] << column
          end
        end
      end

      def apply_remove_references(state, scanner)
        scanner.remove_references.each do |table, ref, opts|
          next unless state[:tables][table]

          remove_reference_columns(state[:tables][table], ref, opts)
        end
      end

      def apply_rename_columns(state, scanner)
        scanner.rename_columns.each do |table, from, to|
          next unless state[:tables][table]

          col = state[:tables][table][:columns].find { |c| c[:name] == from }
          col[:name] = to if col
        end
      end

      def apply_rename_indexes(state, scanner)
        scanner.rename_indexes.each do |table, from, to|
          next unless state[:tables][table]

          from_name = clean_identifier(from)
          to_name = clean_identifier(to)
          idx = state[:tables][table][:indexes].find { |index| index[:name] == from_name }
          idx[:name] = to_name if idx
        end
      end

      def apply_rename_tables(state, scanner)
        scanner.rename_tables.each do |from, to|
          next unless state[:tables][from]

          state[:tables][to] = state[:tables].delete(from)
        end
      end

      def apply_change_columns(state, scanner)
        scanner.change_columns.each do |table, col, type|
          next unless state[:tables][table]

          existing = state[:tables][table][:columns].find { |c| c[:name] == col }
          existing[:type] = type if existing
        end
      end

      def apply_change_column_defaults(state, scanner)
        scanner.change_column_defaults.each do |table, col, options|
          next unless state[:tables][table]

          existing = state[:tables][table][:columns].find { |c| c[:name] == col }
          next unless existing

          existing[:default] = extract_default_value(options)
        end
      end

      def apply_change_column_nulls(state, scanner)
        scanner.change_column_nulls.each do |table, col, nullable, default_value|
          next unless state[:tables][table]

          existing = state[:tables][table][:columns].find { |c| c[:name] == col }
          next unless existing

          existing[:null] = nullable == "true"
          existing[:default] = extract_default_value(default_value) if default_value
        end
      end

      def apply_change_column_comments(state, scanner)
        scanner.change_column_comments.each do |table, col, comment|
          next unless state[:tables][table]

          existing = state[:tables][table][:columns].find { |c| c[:name] == col }
          existing[:comment] = extract_default_value(comment) if existing
        end
      end

      def apply_add_indexes(state, scanner)
        scanner.add_indexes.each do |table, cols_raw, opts|
          next unless state[:tables][table]

          state[:tables][table][:indexes] << build_index(cols_raw, opts)
        end
      end

      def apply_remove_indexes(state, scanner)
        scanner.remove_indexes.each do |table, args|
          next unless state[:tables][table]

          remove_index_from_table(state[:tables][table], args)
        end
      end

      def apply_add_foreign_keys(state, scanner)
        scanner.add_foreign_keys.each do |table, to_table, opts|
          next unless state[:tables][table]

          state[:tables][table][:foreign_keys] << build_foreign_key(to_table, opts)
        end
      end

      def apply_remove_foreign_keys(state, scanner)
        scanner.remove_foreign_keys.each do |table, args|
          next unless state[:tables][table]

          remove_foreign_key_from_table(state[:tables][table], args)
        end
      end

      def apply_add_check_constraints(state, scanner)
        scanner.add_check_constraints.each do |table, expression, opts|
          next unless state[:tables][table]

          state[:tables][table][:check_constraints] << build_check_constraint(expression, opts)
        end
      end

      def apply_remove_check_constraints(state, scanner)
        scanner.remove_check_constraints.each do |table, args|
          next unless state[:tables][table]

          remove_check_constraint_from_table(state[:tables][table], args)
        end
      end

      def apply_change_table_blocks(state, scanner)
        scanner.change_table_blocks.each do |table, block|
          next unless state[:tables][table]

          apply_block_table_changes(state[:tables][table], block)
        end
      end

      def apply_block_table_changes(table_state, block)
        scanner = MigrationDslScanner.new(block)

        add_block_columns_to_table(table_state, scanner, block)
        add_block_indexes_to_table(table_state, scanner, block)
        apply_block_column_changes(table_state, scanner, block)
        remove_block_columns_from_table(table_state, scanner, block)
        apply_block_check_constraints(table_state, scanner, block)
      end

      def add_block_columns_to_table(table_state, scanner, block)
        scanner.block_column_definitions(block).each do |definition|
          if definition.first == :column
            _, name, type, opts = definition
            table_state[:columns] << build_column(name, type, opts)
            next
          end

          type, name, opts = definition
          if reference_type?(type)
            build_reference_columns(name, opts).each { |column| table_state[:columns] << column }
            next
          end
          table_state[:columns] << build_column(name, type, opts)
        end

        return unless scanner.block_has_timestamps?(block)

        table_state[:columns] << { name: "created_at", type: "datetime", null: false, default: nil }
        table_state[:columns] << { name: "updated_at", type: "datetime", null: false, default: nil }
      end

      def add_block_indexes_to_table(table_state, scanner, block)
        scanner.block_add_indexes(block).each do |cols_raw, opts|
          table_state[:indexes] << build_index(cols_raw, opts)
        end
        scanner.block_remove_indexes(block).each do |args|
          remove_index_from_table(table_state, args)
        end
      end

      def apply_block_column_changes(table_state, scanner, block)
        scanner.block_change_defaults(block).each do |col, options|
          existing = table_state[:columns].find { |column| column[:name] == col }
          next unless existing

          existing[:default] = extract_default_value(options)
        end

        scanner.block_change_nulls(block).each do |col, nullable, default_value|
          existing = table_state[:columns].find { |column| column[:name] == col }
          next unless existing

          existing[:null] = nullable == "true"
          existing[:default] = extract_default_value(default_value) if default_value
        end

        scanner.block_rename_indexes(block).each do |from, to|
          from_name = clean_identifier(from)
          to_name = clean_identifier(to)
          idx = table_state[:indexes].find { |index| index[:name] == from_name }
          idx[:name] = to_name if idx
        end
      end

      def remove_block_columns_from_table(table_state, scanner, block)
        scanner.block_remove_columns(block).each do |col|
          table_state[:columns].reject! { |c| c[:name] == col }
        end
        scanner.block_remove_columns_plural(block).each do |cols_raw|
          extract_columns_list(cols_raw).each do |col|
            table_state[:columns].reject! { |c| c[:name] == col }
          end
        end
        scanner.block_remove_references(block).each do |ref, opts|
          remove_reference_columns(table_state, ref, opts)
        end
      end

      def apply_block_check_constraints(table_state, scanner, block)
        scanner.block_add_check_constraints(block).each do |expression, opts|
          table_state[:check_constraints] << build_check_constraint(expression, opts)
        end
        scanner.block_remove_check_constraints(block).each do |args|
          remove_check_constraint_from_table(table_state, args)
        end
      end

      def ensure_table(state, table)
        state[:tables][table] ||= { columns: [], indexes: [], foreign_keys: [], check_constraints: [] }
      end

      def parse_block_columns(block)
        columns = []
        block.scan(/t\.column\s+[:"'](\w+)[:"']?,\s*:?(?:["'])?(\w+)(?:["'])?([^\n]*)/) do |name, type, opts|
          columns << build_column(name, type, opts)
        end

        block.scan(/t\.(\w+)\s+[:"'](\w+)[:"']?([^\n]*)/) do |type, name, opts|
          next if %w[index timestamps].include?(type)
          next if type == "column"

          if reference_type?(type)
            build_reference_columns(name, opts).each { |column| columns << column }
            next
          end
          columns << build_column(name, type, opts)
        end
        if block =~ /t\.timestamps/
          columns << { name: "created_at", type: "datetime", null: false, default: nil }
          columns << { name: "updated_at", type: "datetime", null: false, default: nil }
        end
        columns
      end

      def parse_block_indexes(block)
        MigrationDslScanner.new(block).block_add_indexes(block).map do |cols_raw, opts|
          build_index(cols_raw, opts)
        end
      end

      def reference_type?(type)
        %w[references belongs_to].include?(type)
      end

      def build_reference_columns(name, opts = "")
        columns = [{
          name: "#{name}_id",
          type: reference_id_type(opts),
          null: null_value_for_reference_options(opts),
          default: nil
        }]
        if opts =~ /polymorphic:\s*true/
          columns << {
            name: "#{name}_type",
            type: "string",
            null: null_value_for_reference_options(opts),
            default: nil
          }
        end
        columns
      end

      def remove_reference_columns(table_state, ref, opts = "")
        table_state[:columns].reject! { |c| c[:name] == "#{ref}_id" }
        return unless opts =~ /polymorphic:\s*true/

        table_state[:columns].reject! { |c| c[:name] == "#{ref}_type" }
      end

      def reference_id_type(opts)
        type_match = /type:\s*:?(?:["'])?(\w+)(?:["'])?/.match(opts)
        type_match ? type_match[1] : "bigint"
      end

      def null_value_for_reference_options(opts)
        null_match = /null:\s*(true|false)/.match(opts)
        null_match ? null_match[1] == "true" : true
      end

      def build_column(name, type, opts = "")
        null_match    = /null:\s*(true|false)/.match(opts)
        default_match = /default:\s*([^,\n]+)/.match(opts)
        limit_match   = /limit:\s*(\d+)/.match(opts)
        col = {
          name: name,
          type: type,
          null: null_match ? null_match[1] == "true" : true,
          default: default_match ? default_match[1].strip : nil
        }
        col[:limit] = limit_match[1].to_i if limit_match
        col[:precision] = extract_numeric_option(opts, "precision")
        col[:scale] = extract_numeric_option(opts, "scale")
        col[:comment] = extract_string_option(opts, "comment")
        col
      end

      def build_index(cols_raw, opts)
        name_match = /name:\s*"([^"]+)"/.match(opts)
        unique     = /unique:\s*true/.match?(opts)
        cols = if cols_raw.start_with?("[")
                 cols_raw.scan(/[:"'](\w+)[:"']?/).flatten
               else
                 [cols_raw.gsub(/['":,\s]/, "")]
               end
        { name: name_match&.[](1), columns: cols, unique: unique }
      end

      def build_foreign_key(to_table, opts)
        {
          to_table: to_table,
          column: extract_string_option(opts, "column"),
          primary_key: extract_string_option(opts, "primary_key"),
          name: extract_string_option(opts, "name")
        }
      end

      def build_check_constraint(expression, opts)
        {
          expression: expression,
          name: extract_string_option(opts, "name")
        }
      end

      def remove_index_from_table(table_state, args)
        name_match = /name:\s*["']([^"']+)["']/.match(args)
        return table_state[:indexes].reject! { |idx| idx[:name] == name_match[1] } if name_match

        column_match = /column:\s*(\[.*?\]|[:"']\w+[:"']?)/.match(args)
        cols_raw = column_match ? column_match[1] : args
        columns = parse_columns_arg(cols_raw)
        table_state[:indexes].reject! { |idx| idx[:columns] == columns }
      end

      def remove_foreign_key_from_table(table_state, args)
        name_match = /name:\s*["']([^"']+)["']/.match(args)
        if name_match
          table_state[:foreign_keys].reject! { |fk| fk[:name] == name_match[1] }
          return
        end

        to_table_match = /[:"'](\w+)[:"']?/.match(args)
        return unless to_table_match

        table_state[:foreign_keys].reject! { |fk| fk[:to_table] == to_table_match[1] }
      end

      def remove_check_constraint_from_table(table_state, args)
        name_match = /name:\s*["']([^"']+)["']/.match(args)
        if name_match
          table_state[:check_constraints].reject! { |cc| cc[:name] == name_match[1] }
          return
        end

        expr_match = /["'](.+?)["']/.match(args)
        return unless expr_match

        table_state[:check_constraints].reject! { |cc| cc[:expression] == expr_match[1] }
      end

      def clean_identifier(raw)
        raw.to_s.gsub(/['":,\s]/, "")
      end

      def extract_default_value(raw)
        return nil unless raw

        to_match = /to:\s*([^,}\n]+)/.match(raw)
        value = to_match ? to_match[1].strip : raw.strip
        value.gsub(/\A["']|["']\z/, "")
      end

      def extract_string_option(raw, key)
        return nil unless raw

        match = /#{key}:\s*(?:["']([^"']+)["']|:(\w+)|([^,\n]+))/.match(raw)
        return nil unless match

        (match[1] || match[2] || match[3]).to_s.strip
      end

      def extract_numeric_option(raw, key)
        return nil unless raw

        match = /#{key}:\s*(\d+)/.match(raw)
        match ? match[1].to_i : nil
      end

      def extract_columns_list(raw)
        columns_part = raw.split(/,\s*\w+:\s*/).first.to_s
        columns_part.scan(/[:"'](\w+)[:"']?/).flatten
      end

      def parse_columns_arg(cols_raw)
        return cols_raw.scan(/[:"'](\w+)[:"']?/).flatten if cols_raw.start_with?("[")

        [cols_raw.gsub(/['":,\s]/, "")]
      end

      def calculate_diff(before, after)
        {
          added_tables: after[:tables].keys - before[:tables].keys,
          removed_tables: before[:tables].keys - after[:tables].keys,
          modified_tables: modified_tables_diff(before, after)
        }
      end

      def modified_tables_diff(before, after)
        common = before[:tables].keys & after[:tables].keys
        common.each_with_object({}) do |table, result|
          before_cols = before[:tables][table][:columns].map { |c| c[:name] }
          after_cols  = after[:tables][table][:columns].map { |c| c[:name] }
          added   = after_cols - before_cols
          removed = before_cols - after_cols
          result[table] = { added_columns: added, removed_columns: removed } if added.any? || removed.any?
        end
      end
    end
  end
end
