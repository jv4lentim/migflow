# frozen_string_literal: true

module Migflow
  module Models
    Warning = Data.define(:rule, :severity, :table, :column, :message)
  end
end
