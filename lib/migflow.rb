# frozen_string_literal: true

require "migflow/version"
require "migflow/engine"
require "migflow/configuration"
require "migflow/parsers/migration_parser"
require "migflow/parsers/schema_parser"
require "migflow/analyzers/audit_analyzer"
require "migflow/models/migration_snapshot"
require "migflow/models/schema_diff"
require "migflow/models/warning"
require "migflow/services/schema_builder"
require "migflow/services/diff_builder"
require "migflow/services/migration_dsl_scanner"
require "migflow/services/migration_summary_builder"
require "migflow/services/snapshot_builder"
require "migflow/services/schema_patch_builder"
require "migflow/services/touched_tables_from_migration"
require "migflow/services/scoped_migration_warnings"
require "migflow/services/risk_scorer"

module Migflow
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end
  end
end
