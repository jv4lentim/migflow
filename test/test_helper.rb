# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "pathname"
require "migrail/version"
require "migrail/models/warning"
require "migrail/models/migration_snapshot"
require "migrail/models/schema_diff"
require "migrail/parsers/migration_parser"
require "migrail/parsers/schema_parser"
require "migrail/analyzers/rules/base_rule"
require "migrail/analyzers/rules/missing_index_rule"
require "migrail/analyzers/rules/missing_foreign_key_rule"
require "migrail/analyzers/rules/string_without_limit_rule"
require "migrail/analyzers/rules/missing_timestamps_rule"
require "migrail/analyzers/rules/dangerous_migration_rule"
require "migrail/analyzers/rules/null_column_without_default_rule"

require "minitest/autorun"

FIXTURES_PATH = Pathname.new(File.expand_path("fixtures", __dir__))
