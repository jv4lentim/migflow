# frozen_string_literal: true

module Migflow
  module Services
    class SchemaPatchBuilder
      def self.call(from_tables:, to_tables:, changed_tables: nil, include_unchanged: false)
        new(
          from_tables: from_tables || {},
          to_tables: to_tables || {},
          changed_tables: changed_tables,
          include_unchanged: include_unchanged
        ).build
      end

      def initialize(from_tables:, to_tables:, changed_tables:, include_unchanged:)
        @from_tables = from_tables
        @to_tables = to_tables
        @changed_tables = changed_tables&.to_set
        @include_unchanged = include_unchanged
      end

      def build
        document = build_document
        lines = document[:lines]
        has_diff = lines.any? { |line| ["+", "-"].include?(line[:prefix]) }
        return "" unless has_diff

        return build_full_patch(lines) if @include_unchanged

        build_collapsed_patch(lines, document[:sections])
      end

      private

      def build_full_patch(lines)
        old_count = lines.count { |line| line[:prefix] != "+" }
        new_count = lines.count { |line| line[:prefix] != "-" }

        [
          "diff --git a/schema.rb b/schema.rb",
          "--- a/schema.rb",
          "+++ b/schema.rb",
          "@@ -1,#{old_count} +1,#{new_count} @@",
          *lines.map { |line| "#{line[:prefix]}#{line[:content]}" },
          ""
        ].join("\n")
      end

      def build_collapsed_patch(lines, sections)
        hunk_ranges = table_hunk_ranges(lines, sections)
        return "" if hunk_ranges.empty?

        hunk_blocks = hunk_ranges.map do |range|
          old_start = line_number_before(lines, range.begin, :old) + 1
          new_start = line_number_before(lines, range.begin, :new) + 1
          hunk_lines = lines[range]
          old_count = hunk_lines.count { |line| line[:prefix] != "+" }
          new_count = hunk_lines.count { |line| line[:prefix] != "-" }

          [
            "@@ -#{old_start},#{old_count} +#{new_start},#{new_count} @@",
            *hunk_lines.map { |line| "#{line[:prefix]}#{line[:content]}" }
          ].join("\n")
        end

        [
          "diff --git a/schema.rb b/schema.rb",
          "--- a/schema.rb",
          "+++ b/schema.rb",
          *hunk_blocks,
          ""
        ].join("\n")
      end

      def table_hunk_ranges(lines, sections)
        sections.each_with_object([]) do |section, ranges|
          next unless section_changed?(lines, section)

          # Keep schema block anchor visible so columns are not "floating"
          # Always include full table block so each `create_table` has its
          # matching `end` and changes never look nested/confusing.
          ranges << (section[:start]..section[:end])
        end
      end

      def line_number_before(lines, idx_exclusive, side)
        slice = idx_exclusive.zero? ? [] : lines[0...idx_exclusive]
        case side
        when :old
          slice.count { |line| line[:prefix] != "+" }
        when :new
          slice.count { |line| line[:prefix] != "-" }
        else
          0
        end
      end

      def section_changed?(lines, section)
        has_diff_lines = (section[:start]..section[:end]).any? { |idx| %w[+ -].include?(lines[idx][:prefix]) }
        return has_diff_lines if @changed_tables.nil?
        return false unless @changed_tables.include?(section[:table_name])

        has_diff_lines
      end

      def build_document
        lines = []
        sections = []
        all_table_names.each_with_index do |table_name, idx|
          from_t = @from_tables[table_name]
          to_t = @to_tables[table_name]
          section_start = lines.length
          section_lines = table_lines(table_name, from_t, to_t)
          lines.concat(section_lines)
          section_end = lines.length - 1
          sections << { table_name: table_name, start: section_start, end: section_end }
          lines << { prefix: " ", content: "" } if idx < all_table_names.length - 1
        end
        { lines: lines, sections: sections }
      end

      def all_table_names
        (@from_tables.keys + @to_tables.keys).uniq.sort
      end

      def table_lines(table_name, from_t, to_t)
        lines = []
        is_added = from_t.nil? && !to_t.nil?
        is_removed = !from_t.nil? && to_t.nil?

        header_prefix = if is_added
                          "+"
                        else
                          is_removed ? "-" : " "
                        end
        lines << { prefix: header_prefix, content: "create_table \"#{table_name}\" do |t|" }

        from_columns = columns_map(from_t)
        to_columns = columns_map(to_t)
        (from_columns.keys + to_columns.keys).uniq.sort.each do |col_name|
          from_col = from_columns[col_name]
          to_col = to_columns[col_name]
          if from_col.nil?
            lines << { prefix: "+", content: "  #{format_column(to_col)}" }
            next
          end

          if to_col.nil?
            lines << { prefix: "-", content: "  #{format_column(from_col)}" }
            next
          end

          if equivalent_column?(from_col, to_col)
            lines << { prefix: " ", content: "  #{format_column(to_col)}" }
          else
            lines << { prefix: "-", content: "  #{format_column(from_col)}" }
            lines << { prefix: "+", content: "  #{format_column(to_col)}" }
          end
        end

        from_indexes = indexes_map(from_t)
        to_indexes = indexes_map(to_t)
        (from_indexes.keys + to_indexes.keys).uniq.sort.each do |idx_key|
          from_idx = from_indexes[idx_key]
          to_idx = to_indexes[idx_key]
          if from_idx.nil?
            lines << { prefix: "+", content: "  #{format_index(to_idx)}" }
            next
          end

          if to_idx.nil?
            lines << { prefix: "-", content: "  #{format_index(from_idx)}" }
            next
          end

          if equivalent_index?(from_idx, to_idx)
            lines << { prefix: " ", content: "  #{format_index(to_idx)}" }
          else
            lines << { prefix: "-", content: "  #{format_index(from_idx)}" }
            lines << { prefix: "+", content: "  #{format_index(to_idx)}" }
          end
        end

        lines << { prefix: " ", content: "end" }
        lines
      end

      def columns_map(table)
        return {} unless table

        table[:columns].to_h { |col| [col[:name], col] }
      end

      def indexes_map(table)
        return {} unless table

        table[:indexes].each_with_object({}) do |idx, memo|
          key = idx[:name] || idx[:columns].join("_")
          memo[key] = idx
        end
      end

      def format_column(col)
        type = col[:type] || "string"
        opts = []
        opts << "null: false" if col[:null] == false
        opts << "default: #{col[:default]}" unless col[:default].nil?
        opts << "limit: #{col[:limit]}" unless col[:limit].nil?
        base = "t.#{type} \"#{col[:name]}\""
        opts.empty? ? base : "#{base}, #{opts.join(", ")}"
      end

      def format_index(idx)
        columns = "[#{idx[:columns].map { |c| "\"#{c}\"" }.join(", ")}]"
        opts = []
        opts << "name: \"#{idx[:name]}\"" if idx[:name]
        opts << "unique: true" if idx[:unique]
        base = "t.index #{columns}"
        opts.empty? ? base : "#{base}, #{opts.join(", ")}"
      end

      def equivalent_column?(one, other)
        one[:name] == other[:name] &&
          one[:type] == other[:type] &&
          one[:null] == other[:null] &&
          one[:default] == other[:default] &&
          one[:limit] == other[:limit]
      end

      def equivalent_index?(one, other)
        one[:name] == other[:name] &&
          one[:unique] == other[:unique] &&
          one[:columns] == other[:columns]
      end
    end
  end
end
