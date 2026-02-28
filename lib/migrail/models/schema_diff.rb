# frozen_string_literal: true

module Migrail
  module Models
    SchemaDiff = Data.define(:from_version, :to_version, :changes)

    Change = Data.define(:type, :table, :detail)
  end
end
