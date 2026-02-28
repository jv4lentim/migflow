# frozen_string_literal: true

require "migrail/version"
require "migrail/engine"
require "migrail/configuration"
require "migrail/parsers/migration_parser"
require "migrail/parsers/schema_parser"
require "migrail/analyzers/audit_analyzer"
require "migrail/models/migration_snapshot"
require "migrail/models/schema_diff"
require "migrail/models/warning"
require "migrail/services/schema_builder"
require "migrail/services/diff_builder"

module Migrail
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end
  end
end
