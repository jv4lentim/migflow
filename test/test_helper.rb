# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "pathname"
require "migflow/version"
require "migflow/models/warning"
require "migflow/models/migration_snapshot"
require "migflow/models/schema_diff"
require "migflow/parsers/migration_parser"
require "migflow/parsers/schema_parser"
require "migflow/analyzers/rules/base_rule"
require "migflow/analyzers/rules/missing_index_rule"
require "migflow/analyzers/rules/missing_foreign_key_rule"
require "migflow/analyzers/rules/string_without_limit_rule"
require "migflow/analyzers/rules/missing_timestamps_rule"
require "migflow/analyzers/rules/dangerous_migration_rule"
require "migflow/analyzers/rules/null_column_without_default_rule"

require "minitest/autorun"

FIXTURES_PATH = Pathname.new(File.expand_path("fixtures", __dir__))
