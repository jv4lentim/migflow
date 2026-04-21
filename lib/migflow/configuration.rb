# frozen_string_literal: true

module Migflow
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end
  end

  class Configuration
    attr_accessor :migrations_path, :schema_path, :enabled_rules, :authentication_hook, :expose_raw_content,
                  :parent_controller, :unauthenticated_redirect

    def initialize
      @migrations_path          = nil
      @schema_path              = nil
      @enabled_rules            = :all
      @authentication_hook      = nil
      @expose_raw_content       = true
      @parent_controller        = "ActionController::Base"
      @unauthenticated_redirect = nil
    end

    def resolved_migrations_path
      migrations_path || Rails.root.join("db/migrate")
    end

    def resolved_schema_path
      schema_path || Rails.root.join("db/schema.rb")
    end
  end
end
