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
require "migflow/services/snapshot_builder"

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
