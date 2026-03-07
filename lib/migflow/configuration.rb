# frozen_string_literal: true

module Migflow
  class Configuration
    attr_accessor :migrations_path, :schema_path, :enabled_rules

    def initialize
      @migrations_path = nil
      @schema_path     = nil
      @enabled_rules   = :all
    end

    def resolved_migrations_path
      migrations_path || Rails.root.join("db/migrate")
    end

    def resolved_schema_path
      schema_path || Rails.root.join("db/schema.rb")
    end
  end
end
